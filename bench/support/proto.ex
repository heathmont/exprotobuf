defmodule Exprotobuf.Bench.Proto do
  use Protobuf,
    use_package_names: true,
    google_wrappers: true,
    from: Path.expand("../../test/proto/wrappers.proto", __DIR__)
end
