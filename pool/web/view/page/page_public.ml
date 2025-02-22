module Import = Page_public_import
open Tyxml.Html
open Component.Input
module HttpUtils = Http_utils
module Message = Pool_common.Message

let txt_to_string lang m = [ txt (Pool_common.Utils.text_to_string lang m) ]

let login_form
  ?(hide_signup = false)
  ?intended
  ?flash_fetcher
  Pool_context.{ language; query_language; csrf; _ }
  =
  let open Pool_common in
  let externalize = HttpUtils.externalize_path_with_lang query_language in
  let action = HttpUtils.intended_or "/login" intended |> externalize in
  let reset_password =
    a
      ~a:[ a_href (externalize "/request-reset-password") ]
      (txt_to_string language I18n.ResetPasswordLink)
  in
  let sign_up =
    if hide_signup
    then txt ""
    else
      a
        ~a:[ a_href (externalize "/signup") ]
        (txt_to_string language I18n.SignUpTitle)
  in
  div
    ~a:[ a_class [ "stack" ] ]
    [ form
        ~a:[ a_action action; a_method `Post; a_class [ "stack" ] ]
        [ csrf_element csrf ()
        ; input_element ?flash_fetcher language `Email Message.Field.Email
        ; input_element language `Password Message.Field.Password
        ; div
            ~a:[ a_class [ "flexrow"; "align-center"; "flex-gap" ] ]
            [ div
                ~a:[ a_class [ "flexrow"; "flex-gap" ] ]
                [ reset_password; sign_up ]
            ; submit_element ~classnames:[ "push" ] language Message.Login ()
            ]
        ]
    ]
;;

let index
  (tenant : Pool_tenant.t)
  Pool_context.({ language; query_language; user; _ } as context)
  welcome_text
  =
  let text_to_string = Pool_common.Utils.text_to_string language in
  let is_logged_in =
    let open Pool_context in
    match user with
    | Guest -> false
    | Admin _ | Contact _ -> true
  in
  let sign_up_cta =
    match is_logged_in with
    | true -> []
    | false ->
      [ h2
          ~a:[ a_class [ "heading-2" ] ]
          [ txt (text_to_string Pool_common.I18n.DontHaveAnAccount) ]
      ; p Pool_common.[ Utils.text_to_string language I18n.SignUpCTA |> txt ]
      ; div
          ~a:[ a_class [ "flexrow" ] ]
          [ link_as_button
              ~control:(language, Pool_common.Message.SignUp)
              (HttpUtils.path_with_language query_language "/signup")
          ]
      ]
  in
  let aspect_ratio img =
    img |> Component.Image.aspect_ratio ~contain:true `R16x9
  in
  let partner_html =
    let open Pool_tenant in
    let logos = tenant.partner_logo |> PartnerLogos.value in
    if CCList.is_empty logos
    then []
    else
      [ h2
          ~a:[ a_class [ "heading-2" ] ]
          [ txt (text_to_string Pool_common.I18n.OurPartners) ]
      ; div
          ~a:[ a_class [ "grid-col-4"; "flex-gap" ] ]
          (CCList.map
             (fun logo ->
               img ~src:(Pool_common.File.path logo) ~alt:"" () |> aspect_ratio)
             (tenant.Pool_tenant.partner_logo |> Pool_tenant.PartnerLogos.value))
      ]
  in
  div
    ~a:[ a_class [ "trim"; "safety-margin" ] ]
    [ div
        ~a:[ a_class [ "flexrow"; "flex-gap-lg"; "index-page" ] ]
        [ div
            ~a:
              [ a_class
                  [ "bg-grey-light"; "border"; "border-radius"; "inset-lg" ]
              ]
            ([ h1
                 ~a:[ a_class [ "heading-1" ] ]
                 [ txt (text_to_string Pool_common.I18n.HomeTitle) ]
             ; div [ welcome_text |> I18n.content_to_string |> Unsafe.data ]
             ]
             @ sign_up_cta
             @ partner_html)
        ; div
            ~a:[ a_class [ "flexcolumn"; "stack" ] ]
            (CCList.map
               (fun logo ->
                 img
                   ~src:(Pool_common.File.path logo)
                   ~alt:
                     (Format.asprintf
                        "Logo %s"
                        Pool_tenant.(tenant.title |> Title.value))
                   ()
                 |> aspect_ratio)
               (tenant.Pool_tenant.logos |> Pool_tenant.Logos.value)
             @ [ (if is_logged_in
                  then txt ""
                  else login_form ~hide_signup:true context)
               ])
        ]
    ]
;;

let login ?intended Pool_context.({ language; _ } as context) flash_fetcher =
  let txt_to_string = txt_to_string language in
  div
    ~a:[ a_class [ "trim"; "narrow"; "safety-margin" ] ]
    [ h1
        ~a:[ a_class [ "heading-1" ] ]
        (txt_to_string Pool_common.I18n.LoginTitle)
    ; login_form ?intended ~flash_fetcher context
    ]
;;

let request_reset_password Pool_context.{ language; query_language; csrf; _ } =
  div
    ~a:[ a_class [ "trim"; "narrow"; "safety-margin" ] ]
    [ h1
        ~a:[ a_class [ "heading-1" ] ]
        [ txt
            Pool_common.(Utils.text_to_string language I18n.ResetPasswordTitle)
        ]
    ; form
        ~a:
          [ a_action
              (HttpUtils.externalize_path_with_lang
                 query_language
                 "/request-reset-password")
          ; a_method `Post
          ; a_class [ "stack" ]
          ]
        [ csrf_element csrf ()
        ; input_element language `Text Pool_common.Message.Field.Email
        ; div
            ~a:[ a_class [ "flexrow" ] ]
            [ submit_element
                ~classnames:[ "push" ]
                language
                Pool_common.Message.SendResetLink
                ()
            ]
        ]
    ]
;;

let reset_password
  token
  Pool_context.{ language; query_language; csrf; _ }
  password_policy
  =
  let externalize = HttpUtils.externalize_path_with_lang query_language in
  div
    ~a:[ a_class [ "trim"; "narrow"; "safety-margin" ] ]
    [ h1
        ~a:[ a_class [ "heading-1" ] ]
        [ txt
            Pool_common.(Utils.text_to_string language I18n.ResetPasswordTitle)
        ]
    ; form
        ~a:
          [ a_action (externalize "/reset-password")
          ; a_method `Post
          ; a_class [ "stack" ]
          ]
        [ csrf_element csrf ()
        ; input_element language `Hidden Message.Field.Token ~value:token
        ; input_element
            ~help:
              (Pool_common.I18n.I18nText
                 (password_policy |> I18n.content_to_string))
            language
            `Password
            Message.Field.Password
        ; input_element language `Password Message.Field.PasswordConfirmation
        ; div
            ~a:[ a_class [ "flexrow" ] ]
            [ submit_element
                ~classnames:[ "push" ]
                language
                Message.(Save (Some Field.password))
                ()
            ]
        ]
    ]
;;
