defmodule Ortovicino.SecurityTest do
  use ExUnit.Case, async: true
  alias Ortovicino.{Auth, AccountSecurity}
  test "token SHA-256 has a fixed size" do
    assert byte_size(Auth.hash("token")) == 32
    refute Auth.hash("a") == Auth.hash("b")
  end
  test "password recovery refuses inadequate passwords" do
    assert {:error, _} = AccountSecurity.reset("invalid", "short")
  end
  test "email verification refuses invalid tokens" do
    assert {:error, _} = AccountSecurity.consume(nil, "verify")
  end
end
