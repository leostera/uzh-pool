open Tyxml.Html
open Component
open Input
module Message = Pool_common.Message
module Field = Message.Field
module HttpUtils = Http_utils

let control_to_string = Pool_common.Utils.control_to_string

let profile_layout language title html =
  div
    ~a:[ a_class [ "trim"; "safety-margin" ] ]
    [ h1
        ~a:[ a_class [ "heading-1" ] ]
        [ txt (Pool_common.Utils.nav_link_to_string language title) ]
    ; html
    ]
;;

let login_information
  ?(action_prefix = "/admin")
  admin
  Pool_context.{ language; csrf; _ }
  password_policy
  =
  let form_attrs action =
    [ a_method `Post
    ; a_action
        (Format.asprintf "%s%s" action_prefix action
         |> Sihl.Web.externalize_path)
    ; a_class [ "stack" ]
    ]
  in
  let details_form =
    let firstname, lastname =
      Admin.user admin
      |> fun user -> user.Sihl_user.given_name, user.Sihl_user.name
    in
    div
      [ h2
          ~a:[ a_class [ "heading-2" ] ]
          [ control_to_string language Message.(Update (Some Field.Name)) |> txt
          ]
      ; form
          ~a:(form_attrs "/user/update-details")
          [ csrf_element csrf ()
          ; input_element
              language
              `Text
              Field.Firstname
              ~value:(firstname |> CCOption.value ~default:"")
          ; input_element
              language
              `Text
              Field.Lastname
              ~value:(lastname |> CCOption.value ~default:"")
          ; div
              ~a:[ a_class [ "flexrow" ] ]
              [ submit_element
                  ~classnames:[ "push" ]
                  language
                  Message.(Update (Some Field.Name))
                  ()
              ]
          ]
      ]
  in
  let password_form =
    let open Message in
    div
      [ h2
          ~a:[ a_class [ "heading-2" ] ]
          [ control_to_string language Message.(Update (Some Field.password))
            |> txt
          ]
      ; form
          ~a:(form_attrs "/user/update-password")
          [ csrf_element csrf ()
          ; input_element
              language
              `Password
              ~value:""
              Field.CurrentPassword
              ~required:true
          ; input_element
              language
              ~help:
                Pool_common.I18n.(
                  I18nText (password_policy |> I18n.content_to_string))
              `Password
              ~value:""
              Field.NewPassword
              ~required:true
          ; input_element
              language
              `Password
              ~value:""
              Field.PasswordConfirmation
              ~required:true
          ; div
              ~a:[ a_class [ "flexrow" ] ]
              [ submit_element
                  ~classnames:[ "push" ]
                  language
                  Message.(Update (Some Field.password))
                  ()
              ]
          ]
      ]
  in
  div
    [ div
        ~a:[ a_class [ "grid-col-2"; "gap-lg" ] ]
        [ details_form; password_form ]
    ]
  |> profile_layout language Pool_common.I18n.LoginInformation
;;
