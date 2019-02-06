defprotocol Protobuf.PostDecodable do
  @moduledoc """
  Defines the contract for custom post-decode hooks
  """
  @fallback_to_any true

  @doc """
  Function is applied to term of given type after protobuf decode
  """
  def post_decode(term)
end

defimpl Protobuf.PostDecodable, for: Any do
  def post_decode(term), do: term
end
