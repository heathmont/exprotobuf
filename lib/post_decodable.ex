defprotocol Protobuf.PostDecodable do
  @moduledoc """
  Defines the contract for custom post-decode hooks
  """
  @fallback_to_any true

  @doc """
  Function is applied to term of given type after protobuf decode
  """
  def post_decode(term)
  @doc """
  Quoted type of term after applied `post_decode/1` callback, `nil` value means that type is the same
  """
  def post_decoded_type(term)
end

defimpl Protobuf.PostDecodable, for: Any do
  def post_decode(term), do: term
  def post_decoded_type(_), do: nil
end
