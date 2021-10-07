open Tyxml.Html
module HttpUtils = Http_utils

let input_element = Component.input_element

let list csrf tenant_list root_list message () =
  let open Tenant in
  let build_tenant_rows tenant_list =
    CCList.map
      (fun (tenant : Tenant.t) ->
        div
          [ h2 [ txt (tenant.title |> Tenant.Title.value) ]
          ; a
              ~a:
                [ a_href
                    (Sihl.Web.externalize_path
                       (Format.asprintf
                          "/root/tenant/%s"
                          (Pool_common.Id.value tenant.id)))
                ]
              [ txt "detail" ]
          ; hr ()
          ])
      tenant_list
  in
  let build_root_rows root_list =
    let open Sihl.Contract.User in
    let status_toggle (status : Sihl.Contract.User.status) id =
      let text =
        match status with
        | Active -> "Disable"
        | Inactive -> "Enable"
      in
      form
        ~a:
          [ a_action
              (Sihl.Web.externalize_path
                 (Format.asprintf "/root/root/%s/toggle-status" id))
          ; a_method `Post
          ]
        [ input_element `Submit None text ]
    in
    CCList.map
      (fun root ->
        let user = root |> Root.user in
        let status = status_toggle user.status user.id in
        div [ h2 [ txt user.email ]; status; hr () ])
      root_list
  in
  let tenant_list = build_tenant_rows tenant_list in
  let root_list = build_root_rows root_list in
  let fields =
    [ "title", ""
    ; "description", ""
    ; "url", ""
    ; "database_url", ""
    ; "database_label", ""
    ; "smtp_auth_server", ""
    ; "smtp_auth_port", ""
    ; "smtp_auth_username", ""
    ; "smtp_auth_password", ""
    ; "smtp_auth_authentication_method", ""
    ; "smtp_auth_protocol", ""
    ; "styles", ""
    ; "icon", ""
    ; "logos", ""
    ; "partner_logos", ""
    ; "default_language", ""
    ]
  in
  let input_fields =
    CCList.map
      (fun (name, value) -> input_element `Text (Some name) value)
      fields
  in
  let html =
    div
      [ h1 [ txt "Tenants" ]
      ; div tenant_list
      ; form
          ~a:
            [ a_action (Sihl.Web.externalize_path "/root/tenant/create")
            ; a_method `Post
            ]
          ((Component.csrf_element csrf () :: input_fields)
          @ [ input_element `Submit None "Create new" ])
      ; hr ()
      ; h1 [ txt "Root users" ]
      ; div root_list
      ; form
          ~a:[ a_action (Format.asprintf "/root/root/create"); a_method `Post ]
          (CCList.map
             (fun name -> input_element `Text (Some name) "")
             [ "email"; "password"; "firstname"; "lastname" ]
          @ [ input_element `Submit None "Create root" ])
      ]
  in
  Page_layout.create html message ()
;;

let detail csrf (tenant : Tenant.t) message () =
  let open Tenant in
  let open Tenant.SmtpAuth in
  let detail_fields =
    [ "title", Title.value tenant.title
    ; "description", Description.value tenant.description
    ; "url", Url.value tenant.url
    ; "smtp_auth_server", Server.value tenant.smtp_auth.server
    ; "smtp_auth_port", Port.value tenant.smtp_auth.port
    ; "smtp_auth_username", Username.value tenant.smtp_auth.username
    ; ( "smtp_auth_authentication_method"
      , AuthenticationMethod.value tenant.smtp_auth.authentication_method )
    ; "smtp_auth_protocol", Protocol.value tenant.smtp_auth.protocol
    ; "styles", Styles.value tenant.styles
    ; "icon", Icon.value tenant.icon
    ; "logos", Logos.value tenant.logos
    ; "partner_logos", PartnerLogos.value tenant.partner_logos
    ; "default_language", Settings.Language.code tenant.default_language
    ]
  in
  let database_fields =
    [ "database_url", ""
    ; "database_label", Tenant.Database.Label.value tenant.database_label
    ]
  in
  let detail_input_fields =
    CCList.map
      (fun (name, value) -> input_element `Text (Some name) value)
      detail_fields
  in
  let database_input_fields =
    CCList.map
      (fun (name, value) -> input_element `Text (Some name) value)
      database_fields
  in
  let disabled =
    let attributes =
      match tenant.disabled |> Tenant.Disabled.value with
      | true -> [ a_input_type `Checkbox; a_name "disabled"; a_checked () ]
      | false -> [ a_input_type `Checkbox; a_name "disabled" ]
    in
    input ~a:attributes ()
  in
  let html =
    div
      [ h1 [ txt (tenant.Tenant.title |> Tenant.Title.value) ]
      ; form
          ~a:
            [ a_action
                (Sihl.Web.externalize_path
                   (Format.asprintf
                      "/root/tenant/%s/update-detail"
                      (Pool_common.Id.value tenant.id)))
            ; a_method `Post
            ]
          ((Component.csrf_element csrf () :: detail_input_fields)
          @ [ disabled; input_element `Submit None "Update" ])
      ; hr ()
      ; form
          ~a:
            [ a_action
                (Sihl.Web.externalize_path
                   (Format.asprintf
                      "/root/tenant/%s/update-database"
                      (Pool_common.Id.value tenant.id)))
            ; a_method `Post
            ]
          ((Component.csrf_element csrf () :: database_input_fields)
          @ [ input_element `Submit None "Update database" ])
      ; hr ()
      ; form
          ~a:
            [ a_action
                (Format.asprintf
                   "/root/tenant/%s/create-operator"
                   (Pool_common.Id.value tenant.id))
            ; a_method `Post
            ]
          ((Component.csrf_element csrf ()
           :: CCList.map
                (fun name -> input_element `Text (Some name) "")
                [ "email"; "password"; "firstname"; "lastname" ])
          @ [ input_element `Submit None "Create operator" ])
      ; a
          ~a:[ a_href (Sihl.Web.externalize_path "/root/tenants") ]
          [ txt "back" ]
      ]
  in
  Page_layout.create html message ()
;;