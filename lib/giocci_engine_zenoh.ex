defmodule GiocciEngineZenoh do
  @moduledoc false

  use GenServer
  require Logger

  alias GiocciEngine.ModuleDB

  def module_load_and_save({:module_save, encode_module}) do
    {name, binary, path} =
      Giocci.CLI.ModuleConverter.decode(encode_module)

    Logger.info("v module: #{inspect(name)} is loaded.")

    name_snake =
      name
      |> Module.split()
      |> Enum.join("_")
      |> String.to_atom()

    CubDB.put(ModuleDB, name_snake, %{encode_module: encode_module, register_at: get_datetime()})

    Giocci.CLI.ModuleConverter.load({name, binary, path})
  end

  def get_datetime() do
    {{year, month, day}, {time, min, sec}} = :calendar.local_time()

    datetime =
      "#{year}" <>
        "/" <>
        String.pad_leading("#{month}", 2, "0") <>
        "/" <>
        String.pad_leading("#{day}", 2, "0") <>
        " " <>
        String.pad_leading("#{time}", 2, "0") <>
        ":" <>
        String.pad_leading("#{min}", 2, "0") <>
        ":" <>
        String.pad_leading("#{sec}", 2, "0")

    datetime
  end

  defp callback(state, m) do
    ## Clientから送られたデータを解析して、実行する
    %{
      key_expr: erkey,
      value: msgint,
      kind: kind,
      reference: reference
    } = m

    ## msgをバイナリからlistにもどす
    msg =
      msgint
      |> String.trim()
      |> Base.decode64!()
      |> :erlang.binary_to_term()

    case msg do
      ## module_execの場合
      [module, function, arity, :module_exec] = msg ->
        #  module_execする
        module_result_reply = apply(module, function, arity)

        ## 実行結果を(Relayを通して)Clientに返す
        Zenohex.Publisher.put(
          state.publisher,
          (module_result_reply <> " from engine") |> :erlang.term_to_binary() |> Base.encode64()
        )

      ## module_saveの場合
      [encode_module, :module_save] = msg ->
        ## Module_Saveを保存しロードする
        module_save_reply = module_load_and_save({:module_save, encode_module})
        ## ロード結果を(Relayを通して)Clientに返す
        Zenohex.Publisher.put(
          state.publisher,
          module_save_reply |> :erlang.term_to_binary() |> Base.encode64()
        )

      _ = msg ->
        IO.inspect("no match")
    end
  end

  @spec start_link(any()) ::
          {:ok,
           %{
             callback: (any() -> any()),
             id: Relay2Engine2Relaysession,
             subscriber: Zenohex.Subscriber.t()
           }}
  def start_link(relay_name) do
    ## RelayからEngineを通ってRelayに返送するsubとpubをセットアップする
    ## EngineのZenohセッションを起動
    engine_name = System.get_env("MY_NODE_NAME")
    {:ok, session} = Zenohex.open()
    ## pub,subそれぞれのキーをたてる

    {:ok, subscriber} =
      Zenohex.Session.declare_subscriber(session, "from/" <> relay_name <> "/to/" <> engine_name)

    {:ok, publisher} =
      Zenohex.Session.declare_publisher(session, "from/" <> engine_name <> "/to/" <> relay_name)

    ## 状態として次の状態をもつ
    state = %{
      publisher: publisher,
      subscriber: subscriber,
      callback: &callback/2,
      id: Relay2Engine2Relaysession,
      session: session
    }

    ## 上記の状態を保存する用のGenServerの起動
    GenServer.start_link(__MODULE__, state, name: Relay2Engine2Relaysession)
    ## subの開始
    recv_timeout(state)
    {:ok, state}
  end

  def handle_info(:loop, state) do
    # subをループするhandle_info
    recv_timeout(state)
    {:noreply, state}
  end

  defp recv_timeout(state) do
    ## subを永続化する関数

    case Zenohex.Subscriber.recv_timeout(state.subscriber, 10_000) do
      {:ok, sample} ->
        state.callback.(state, sample)
        send(state.id, :loop)

      {:error, :timeout} ->
        send(state.id, :loop)

      {:error, error} ->
        Logger.error(inspect(error))
    end
  end
end
