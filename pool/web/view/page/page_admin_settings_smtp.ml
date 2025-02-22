open Tyxml.Html
open Component.Input
module Icon = Component.Icon
module Message = Pool_common.Message
module Field = Message.Field
module SmtpAuth = Email.SmtpAuth

let base_path = function
  | `Tenant -> "/admin/settings/smtp"
  | `Root -> "/root/settings/smtp"
;;

let index Pool_context.{ language; _ } location smtp_auth_list =
  let thead =
    let add_btn =
      Component.Input.link_as_button
        ~style:`Success
        ~icon:Icon.Add
        ~control:(language, Pool_common.Message.(Add (Some Field.Smtp)))
        (Format.asprintf "%s/new" (base_path location))
    in
    (Pool_common.Message.Field.
       [ Label
       ; SmtpServer
       ; SmtpUsername
       ; SmtpMechanism
       ; SmtpProtocol
       ; DefaultSmtpServer
       ]
     |> Component.Table.fields_to_txt language)
    @ [ add_btn ]
  in
  let rows =
    let open SmtpAuth in
    smtp_auth_list
    |> CCList.map (fun auth ->
      [ auth.label |> Label.value |> txt
      ; auth.server |> Server.value |> txt
      ; auth.username |> CCOption.map_or ~default:"" Username.value |> txt
      ; auth.mechanism |> Mechanism.show |> txt
      ; auth.protocol |> Protocol.show |> txt
      ; auth.default |> Default.value |> Utils.Bool.to_string |> txt
      ; edit_link
          (Format.asprintf "%s/%s" (base_path location) (auth.id |> Id.value))
      ])
  in
  div
    ~a:[ a_class [ "trim"; "safety-margin" ] ]
    [ h1 ~a:[ a_class [ "heading-1" ] ] [ txt "Email Server Settings (SMTP)" ]
    ; Component.Table.horizontal_table `Striped ~align_last_end:true ~thead rows
    ]
;;

let show
  Pool_context.{ language; csrf; _ }
  location
  flash_fetcher
  { SmtpAuth.id; label; server; port; username; mechanism; protocol; default }
  =
  let action_path sub =
    Sihl.Web.externalize_path
      (Format.asprintf
         "%s/%s%s"
         (base_path location)
         (SmtpAuth.Id.value id)
         sub)
  in
  let submit
    ?submit_type
    ?(has_icon = Icon.Save)
    ?(control = Message.(Update None))
    ()
    =
    div
      ~a:[ a_class [ "flexrow" ] ]
      [ submit_element
          ?submit_type
          ~has_icon
          ~classnames:[ "push" ]
          language
          control
          ()
      ]
  in
  let form_attrs action_path =
    [ a_method `Post
    ; a_action action_path
    ; a_class [ "stack" ]
    ; a_user_data "detect-unsaved-changes" ""
    ]
  in
  let input_element_root
    ?(required = true)
    ?(field_type = `Text)
    field
    decode_fcn
    value
    =
    input_element
      ~required
      ~value:(value |> decode_fcn)
      ~flash_fetcher
      language
      field_type
      field
  in
  let smtp_details =
    let open SmtpAuth in
    div
      [ form
          ~a:(action_path "" |> form_attrs)
          [ csrf_element csrf ()
          ; input_element_root Field.SmtpLabel Label.value label
          ; input_element_root Field.SmtpServer Server.value server
          ; input_element_root
              ~field_type:`Number
              Field.SmtpPort
              CCFun.(Port.value %> CCInt.to_string)
              port
          ; input_element
              ?value:(CCOption.map Username.value username)
              language
              `Text
              Field.SmtpUsername
          ; selector
              ~required:true
              language
              Field.SmtpMechanism
              Mechanism.show
              Mechanism.all
              (Some mechanism)
              ()
          ; selector
              ~required:true
              language
              Field.SmtpProtocol
              Protocol.show
              Protocol.all
              (Some protocol)
              ()
          ; checkbox_element
              ~value:(Default.value default)
              ~help:Pool_common.I18n.SmtpSettingsDefaultFlag
              language
              Field.DefaultSmtpServer
          ; submit ()
          ]
      ]
  in
  let smtp_password =
    div
      ~a:[ a_class [ "stack" ] ]
      [ h2 ~a:[ a_class [ "heading-2" ] ] [ txt "Update or Delete Password" ]
      ; form
          ~a:(action_path "/password" |> form_attrs)
          [ csrf_element csrf ()
          ; input_element
              ~value:""
              ~required:true
              language
              `Password
              Field.SmtpPassword
          ; submit ()
          ]
      ; form
          ~a:(action_path "/password" |> form_attrs)
          [ csrf_element csrf ()
          ; input_element ~value:"" language `Hidden Field.SmtpPassword
          ; submit
              ~submit_type:`Error
              ~has_icon:Icon.Trash
              ~control:(Message.Delete (Some Field.Password))
              ()
          ]
      ]
  in
  div
    ~a:[ a_class [ "trim"; "narrow"; "safety-margin" ] ]
    [ h1 ~a:[ a_class [ "heading-1" ] ] [ txt "Email Server Settings (SMTP)" ]
    ; p
        [ Pool_common.(Utils.hint_to_string language I18n.SmtpSettingsIntro)
          |> HttpUtils.add_line_breaks
        ]
    ; div ~a:[ a_class [ "stack" ] ] [ smtp_details; smtp_password ]
    ]
;;

(* TODO: Add option to force default *)
let smtp_create_form Pool_context.{ language; csrf; _ } location flash_fetcher =
  let action_path =
    location
    |> base_path
    |> Format.asprintf "%s/create"
    |> Sihl.Web.externalize_path
  in
  let submit () =
    div
      ~a:[ a_class [ "flexrow" ] ]
      [ submit_element
          ~has_icon:Icon.Save
          ~classnames:[ "push" ]
          language
          Message.(Create None)
          ()
      ]
  in
  let create_form =
    let open SmtpAuth in
    let required = true in
    form
      ~a:
        [ a_method `Post
        ; a_action action_path
        ; a_class [ "stack" ]
        ; a_user_data "detect-unsaved-changes" ""
        ]
      [ csrf_element csrf ()
      ; input_element ~required ~flash_fetcher language `Text Field.SmtpLabel
      ; input_element ~required ~flash_fetcher language `Text Field.SmtpServer
      ; input_element ~required ~flash_fetcher language `Number Field.SmtpPort
      ; input_element ~flash_fetcher language `Text Field.SmtpUsername
      ; input_element language `Password Field.SmtpPassword
      ; selector
          ~required
          ~flash_fetcher
          language
          Field.SmtpMechanism
          Mechanism.show
          Mechanism.all
          None
          ()
      ; selector
          ~required
          ~flash_fetcher
          language
          Field.SmtpProtocol
          Protocol.show
          Protocol.all
          None
          ()
      ; checkbox_element
          ~flash_fetcher
          ~help:Pool_common.I18n.SmtpSettingsDefaultFlag
          language
          Field.DefaultSmtpServer
      ; submit ()
      ]
  in
  div
    ~a:[ a_class [ "trim"; "narrow"; "safety-margin" ] ]
    [ h1 ~a:[ a_class [ "heading-1" ] ] [ txt "Configure Email Server (SMTP)" ]
    ; p
        [ Pool_common.(Utils.hint_to_string language I18n.SmtpSettingsIntro)
          |> HttpUtils.add_line_breaks
        ]
    ; div ~a:[ a_class [ "stack" ] ] [ div [ create_form ] ]
    ]
;;
