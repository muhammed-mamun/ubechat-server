defmodule Ubechat.Embeddings do
  @moduledoc "Generates text embeddings using Bumblebee and Nx on the highly optimized EXLA backend."

  @doc "Returns the Nx Serving config to attach to the OTP application tree."
  def serving do
    {:ok, model_info} = Bumblebee.load_model({:hf, "sentence-transformers/all-MiniLM-L6-v2"})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, "sentence-transformers/all-MiniLM-L6-v2"})

    Bumblebee.Text.TextEmbedding.text_embedding(model_info, tokenizer,
      output_pool: :mean_pooling,
      compile: [batch_size: 1, sequence_length: 256],
      defn_options: [compiler: EXLA]
    )
  end

  @doc """
  Takes a raw string (batch or single) and uses the active `all-MiniLM-L6-v2` instance 
  to yield a 384-dimensional Pgvector-compatible Float list embedding natively.
  """
  def generate(text) when is_binary(text) do
    # Pass the text to our supervised Nx serving instance
    result = Nx.Serving.batched_run(Ubechat.Embeddings.Serving, text)
    
    # Extract the tensor into a flat list of floats
    Nx.to_flat_list(result.embedding)
  end
end
