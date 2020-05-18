defmodule OktaAuth.Okta do
  @moduledoc """
  Implements strategy for authenticating with Okta.
  """
  use ExOAuth2.Strategy
  
  @doc """
  Creates a new ExOAuth2 client that will be used to
  communicate with Okta 
  """
  def client do
    config = :okta_auth
             |> Application.fetch_env!(__MODULE__)
             |> validate_config!(:client_id)
             |> validate_config!(:client_secret)
             |> validate_config!(:site)
             |> validate_config!(:redirect_uri)
      
    
    site = Keyword.get(config, :site)
    ExOAuth2.Client.new([
      strategy: __MODULE__,
      client_id: Keyword.get(config, :client_id),
      client_secret: Keyword.get(config, :client_secret),
      site: site,
      redirect_uri: Keyword.get(config, :redirect_uri),
      authorize_url: site <> "/v1/authorize",
      token_url: site <> "/v1/token"
    ])
    |> ExOAuth2.Client.put_serializer("application/json", Jason)
  end

  @doc """
  Given necessary arguments generates authorization
  URL and parameters for interacting with Okta as a provider
  """
  def authorize_url! do
      ExOAuth2.Client.authorize_url!(
          client(), 
          response_type: "code",
          scope: "openid profile email",
          nonce: :crypto.strong_rand_bytes(18) |> Base.encode16 |> String.downcase,
          state: Base.encode16(:crypto.strong_rand_bytes(18))
      )
      |> URI.parse()
      |> URI.to_string()
  end

  @doc """
  Retrieve an access token but does not send 
  the authorization header to authorization server. 
  This is necessary in the case of okta since since otherwise
  okta will complain.
  """
  def get_token_without_auth!(params \\ [], headers \\ [], opts \\ []) do
      client = client()
      headers = List.keystore(headers, "accept", 1, {"accept", "*/*"})
      params = Keyword.put(params, :client_secret, client.client_secret)
      ExOAuth2.Client.get_token_without_auth!(client, params, headers, opts)
      |> IO.inspect
  end

  @doc """
  Retrieve an access token and authenticate via authentication header
  """
  def get_token!(params \\ [], headers \\ [], opts \\ []) do
      client = client()
      params = Keyword.put(params, :client_secret, client.client_secret)
      ExOAuth2.Client.get_token!(client, params, headers, opts)
      |> IO.inspect
  end

  def authorize_url(client, params) do
      ExOAuth2.Strategy.AuthCode.authorize_url(client, params)
  end

  @doc """ 
  Retrieve an access token but does not send authorization header to authorization server
  """
  def get_token_without_auth(client, params, headers) do
      client
      |> ExOAuth2.Strategy.AuthCode.get_token_without_auth(params, headers)
      |> IO.inspect
  end

  def get_token(client, params, headers) do
      client
      |> ExOAuth2.Strategy.AuthCode.get_token(params, headers)
      |> IO.inspect
  end

  @doc """
  Retrieve the authenticated users profile information
  """
  def get_user_info(client, headers \\ [], opts \\ []) do
      headers = List.keystore(headers, "authorization", 1, {"authorization", "Bearer " <> client.token.access_token})
      client
      |> ExOAuth2.Client.get(client.site <> "/v1/userinfo", headers, opts)
      |> IO.inspect
  end

  defp validate_config!(_, _) do
     raise "config: okta_auth, OktaAuth, expects a keyword list"
  end 

  defp validate_config!(config, key) when is_list(config) do
    with val when is_bitstring(val) <- Keyword.get(config, key),
         {^key, true} <- if(key == :site, do: {key, String.starts_with?(val, "http")}, else: {key, val != ""})
    do
      config
    else
      false -> raise "#{inspect(key)} in okta_auth, OktaAuth, must be a bitstring"
      {:redirect_uri, false} -> raise ":redirect_uri in config okta_auth, OktaAuth, is not a valid url"
      {:site, false} -> raise ":site in config okta_auth, OktaAuth, is not a valid url"
      {key, false} -> raise "#{inspect(key)} in okta_auth, OktaAuth, is an empty string"
    end
  end
end