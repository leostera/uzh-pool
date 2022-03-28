open Tyxml.Html
open Component
module Message = Pool_common.Message

let detail participant Pool_context.{ language; query_language; _ } =
  let open Participant in
  let text_to_string = Pool_common.Utils.text_to_string language in
  let content =
    div
      [ div
          ([ h1 [ txt (text_to_string Pool_common.I18n.UserProfileTitle) ]
           ; p [ participant |> fullname |> Format.asprintf "Name: %s" |> txt ]
           ]
          @
          if participant.paused |> Pool_user.Paused.value
          then
            [ p [ txt (text_to_string Pool_common.I18n.UserProfilePausedNote) ]
            ]
          else [])
      ; a
          ~a:
            [ a_href
                (HttpUtils.externalize_path_with_lang
                   query_language
                   "/user/edit")
            ]
          [ txt
              Pool_common.(Utils.control_to_string language (Message.Edit None))
          ]
      ]
  in
  div [ content ]
;;

let edit
    csrf
    user_update_csrf
    (participant : Participant.t)
    tenant_languages
    Pool_context.{ language; query_language; _ }
  =
  let open Participant in
  let externalize = HttpUtils.externalize_path_with_lang query_language in
  let text_to_string = Pool_common.Utils.text_to_string language in
  let input_element = input_element language in
  let form_attrs action =
    [ a_method `Post; a_action (externalize action); a_class [ "stack" ] ]
  in
  let details_form =
    let action = "/user/update" in
    form
      ~a:(form_attrs action)
      (CCList.flatten
         [ [ Component.csrf_element csrf ~id:user_update_csrf () ]
         ; CCList.map
             (fun htmx_element ->
               Htmx.create htmx_element language ~hx_post:action ())
             Htmx.
               [ Firstname
                   (participant.firstname_version, participant |> firstname)
               ; Lastname (participant.lastname_version, participant |> lastname)
               ; Paused (participant.paused_version, participant.paused)
               ; Language
                   ( participant.language_version
                   , participant.language
                   , tenant_languages )
               ]
         ])
  in
  let email_form =
    form
      ~a:(form_attrs "/user/update-email")
      [ csrf_element csrf ()
      ; input_element
          `Email
          (Some "email")
          Message.Email
          participant.user.Sihl_user.email
      ; submit_element
          language
          Message.(Update (Some Message.email))
          ~classnames:[ "button--primary" ]
          ()
      ]
  in
  let password_form =
    form
      ~a:(form_attrs "/user/update-password")
      [ csrf_element csrf ()
      ; input_element
          `Password
          (Some "current_password")
          Message.CurrentPassword
          ""
      ; input_element `Password (Some "new_password") Message.NewPassword ""
      ; input_element
          `Password
          (Some "password_confirmation")
          Message.PasswordConfirmation
          ""
      ; submit_element
          language
          Message.(Update (Some Message.password))
          ~classnames:[ "button--primary" ]
          ()
      ]
  in
  div
    [ h1 [ txt (text_to_string Pool_common.I18n.UserProfileTitle) ]
    ; div
        [ div
            [ h2
                [ txt
                    (text_to_string Pool_common.I18n.UserProfileDetailsSubtitle)
                ]
            ; details_form
            ]
        ; hr ()
        ; div
            [ h2
                [ txt (text_to_string Pool_common.I18n.UserProfileLoginSubtitle)
                ]
            ; email_form
            ; password_form
            ]
        ]
    ; a
        ~a:[ a_href (Sihl.Web.externalize_path "/user") ]
        [ txt Pool_common.(Utils.control_to_string language Message.Back) ]
    ]
;;
