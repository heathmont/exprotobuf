defmodule Exprotobuf.EncodeTryValidateBench do
  use Benchfella
  require Exprotobuf.Bench.Proto.Helper, as: Helper

  @msg5 Helper.msg(5)

  bench "pure" do
    @msg5
    |> Helper.encode_pure()
  end

  bench "validate" do
    @msg5
    |> Helper.encode_validate()
  end

  bench "try" do
    @msg5
    |> Helper.encode_try()
  end
end
