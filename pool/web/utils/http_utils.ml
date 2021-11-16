module Message = Http_utils_message
module File = Http_utils_file
module StringMap = CCMap.Make (CCString)

let redirect_to_with_actions path actions =
  path
  |> Sihl.Web.externalize_path
  |> Sihl.Web.Response.redirect_to
  |> CCList.fold_left CCFun.( % ) CCFun.id actions
  |> Lwt.return
;;

let redirect_to path = redirect_to_with_actions path []

let extract_happy_path_generic result msgf =
  result
  |> Pool_common.Utils.with_log_result_error (fun (err, _) -> err)
  |> CCResult.map Lwt.return
  |> CCResult.get_lazy (fun (error_msg, error_path) ->
         redirect_to_with_actions error_path [ msgf error_msg ])
;;

let extract_happy_path result =
  extract_happy_path_generic result (fun err ->
      Message.set ~warning:[] ~success:[] ~info:[] ~error:[ err ])
;;

let extract_happy_path_with_actions result =
  result
  |> Pool_common.Utils.with_log_result_error (fun (err, _, _) -> err)
  |> CCResult.map Lwt.return
  |> CCResult.get_lazy (fun (error_key, error_path, error_actions) ->
         redirect_to_with_actions
           error_path
           (CCList.append
              [ Message.set
                  ~warning:[]
                  ~success:[]
                  ~info:[]
                  ~error:[ error_key ]
              ]
              error_actions))
;;

(* Read urlencoded values in any order *)
let urlencoded_to_params_opt urlencoded keys =
  keys
  |> CCList.map @@ fun key -> key, CCList.assoc_opt ~eq:( = ) key urlencoded
;;

let urlencoded_to_params urlencoded keys =
  keys
  |> (CCList.map
     @@ fun key ->
     CCOption.bind (List.assoc_opt key urlencoded) CCList.head_opt
     |> CCOption.map @@ CCPair.make key)
  |> CCList.all_some
;;

let request_to_params req keys () =
  let%lwt urlencoded = Sihl.Web.Request.to_urlencoded req in
  urlencoded_to_params urlencoded keys
  |> CCOption.to_result Pool_common.Message.RequestRequiredFields
  |> Lwt_result.lift
;;

let urlencoded_to_flash urlencoded =
  Sihl.Web.Flash.set (urlencoded |> CCList.map (fun (m, k) -> m, CCList.hd k))
;;

let validate_email_existance pool email =
  let open Lwt.Infix in
  Service.User.find_by_email_opt ~ctx:(Pool_common.Utils.pool_to_ctx pool) email
  >|= function
  | None -> Ok ()
  | Some _ -> Error Pool_common.Message.EmailAlreadyInUse
;;

let format_request_boolean_values values urlencoded =
  let urlencoded = urlencoded |> CCList.to_seq |> StringMap.of_seq in
  let update m k =
    StringMap.update
      k
      (function
        | None -> Some [ "false" ]
        | Some _ -> Some [ "true" ])
      m
  in
  CCList.fold_left update urlencoded values |> StringMap.to_seq |> CCList.of_seq
;;

let placeholder_from_name = CCString.replace ~which:`All ~sub:"_" ~by:" "
let find_csrf req = Sihl.Web.Csrf.find_exn req
