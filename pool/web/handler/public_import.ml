open Utils.Lwt_result.Infix
open Pool_common.Message

let src = Logs.Src.create "handler.public.import"

let import_pending req =
  let open Pool_common.I18n in
  General.note ~title:ImportPendingTitle ~body:ImportPendingNote req
;;

let user_and_import_from_token database_label token =
  let open Pool_context in
  token
  |> User_import.find_pending_by_token database_label
  >>= fun ({ User_import.user_uuid; _ } as import) ->
  user_uuid
  |> Pool_common.Id.value
  |> Service.User.find ~ctx:(Pool_database.to_ctx database_label)
  >|> user_of_sihl_user database_label
  ||> fun user ->
  match user with
  | Guest -> Error Field.(Invalid Token)
  | Admin _ | Contact _ -> Ok (import, user)
;;

let import_confirmation req =
  let result
    ({ Pool_context.database_label; language; query_language; _ } as context)
    =
    let error_path = Http_utils.path_with_language query_language "/index" in
    Utils.Lwt_result.map_error (fun err -> err, error_path)
    @@ let* ({ User_import.token; _ }, _) : User_import.t * Pool_context.user =
         Sihl.Web.Request.query Field.(show Token) req
         |> CCOption.to_result Field.(NotFound Token)
         |> Lwt_result.lift
         >== User_import.Token.create
         >>= user_and_import_from_token database_label
       in
       let%lwt password_policy =
         I18n.find_by_key database_label I18n.Key.PasswordPolicyText language
       in
       let%lwt terms = Settings.terms_and_conditions database_label language in
       Page.Public.Import.import_confirmation
         context
         token
         password_policy
         terms
       |> General.create_tenant_layout req context
       >|+ Sihl.Web.Response.of_html
  in
  result |> Http_utils.extract_happy_path ~src req
;;

let import_confirmation_post req =
  let tags = Pool_context.Logger.Tags.req req in
  let result { Pool_context.database_label; query_language; _ } =
    let%lwt urlencoded =
      let open Http_utils in
      Sihl.Web.Request.to_urlencoded req
      ||> remove_empty_values
      ||> format_request_boolean_values Field.[ show TermsAccepted ]
    in
    let error_path token =
      let open CCOption.Infix in
      [ Field.Language, query_language >|= Pool_common.Language.show
      ; Field.Token, token >|= User_import.Token.value
      ]
      |> CCList.filter_map (fun (key, value) -> value >|= CCPair.make key)
      |> Pool_common.Message.add_field_query_params "/import-confirmation"
    in
    let* ({ User_import.token; _ } as user_import), user =
      urlencoded
      |> Http_utils.find_in_urlencoded Field.Token
      |> Lwt_result.lift
      >== User_import.Token.create
      >>= user_and_import_from_token database_label
      >|- fun err -> err, error_path None
    in
    let* () =
      Helpers.terms_and_conditions_accepted urlencoded
      >|- fun err -> err, error_path (Some token)
    in
    let* events =
      let open CCResult in
      let open Cqrs_command.User_import_command.ConfirmImport in
      urlencoded
      |> decode
      >>= handle (user_import, user)
      |> Lwt_result.lift
      >|- fun err -> err, error_path (Some token)
    in
    let%lwt () = Pool_event.handle_events ~tags database_label events in
    Http_utils.(
      redirect_to_with_actions
        (path_with_language query_language "/login")
        [ Message.set ~success:[ ImportCompleted ] ])
    |> Lwt_result.ok
  in
  result |> Http_utils.extract_happy_path ~src req
;;
