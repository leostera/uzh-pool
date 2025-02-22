module Tenant_command = Cqrs_command.Tenant_command
module Pool_tenant_command = Cqrs_command.Pool_tenant_command
module Admin_command = Cqrs_command.Admin_command
module HttpUtils = Http_utils
module Common = Pool_common
module SmtpAuth = Email.SmtpAuth

let fail_with = Test_utils.get_or_failwith

module Data = struct
  open Database.SeedAssets

  module Asset = struct
    let styles = dummy_css () |> fun { id; _ } -> id
    let icon = dummy_icon () |> fun { id; _ } -> id
    let tenant_logo = dummy_tenant_logo () |> fun { id; _ } -> id
    let partner_logo = dummy_partner_logo () |> fun { id; _ } -> id
  end

  let title = "Econ uzh"
  let description = "description"
  let url = "pool.econ.uzh.ch"

  let database_url =
    Sihl.Configuration.read_string "DATABASE_URL_TENANT_TEST"
    |> CCOption.get_exn_or "DATABASE_URL_TENANT_TEST undefined"
  ;;

  let database_label = "econ-test"

  let database =
    let open Pool_database in
    let label = Label.create database_label |> fail_with in
    let url = Pool_database.Url.create database_url |> fail_with in
    create label url |> fail_with
  ;;

  let styles = Asset.styles |> Pool_tenant.Styles.Write.create |> fail_with
  let icon = Asset.icon |> Pool_tenant.Icon.Write.create |> fail_with
  let tenant_logo = Asset.tenant_logo
  let partner_logo = Asset.partner_logo
  let default_language = "EN"
  let gtx_api_key = "GTX API KEY"
  let email = "operator@econ.uzh.ch"
  let password = "AdminAdmin99!"
  let firstname = "DJ"
  let lastname = "Ötzi"

  let urlencoded =
    let open Common.Message in
    [ Field.Title, [ title ]
    ; Field.Description, [ description ]
    ; Field.Url, [ url ]
    ; Field.DatabaseUrl, [ database_url ]
    ; Field.DatabaseLabel, [ database_label ]
    ; Field.GtxApiKey, [ gtx_api_key ]
    ; Field.Styles, [ Asset.styles ]
    ; Field.Icon, [ Asset.icon ]
    ; Field.TenantLogos, [ tenant_logo ]
    ; Field.PartnerLogos, [ partner_logo ]
    ; Field.Language, [ default_language ]
    ; Field.Email, [ email ]
    ; Field.Password, [ password ]
    ; Field.Firstname, [ firstname ]
    ; Field.Lastname, [ lastname ]
    ]
    |> CCList.map (CCPair.map_fst Field.show)
  ;;

  module Smtp = struct
    let id = SmtpAuth.Id.create ()
    let label = database_label
    let server = "smtp.uzh.ch"
    let port = 587
    let username = "engineering@econ.uzh.ch"
    let password = "emailemail"
    let mechanism = SmtpAuth.Mechanism.(LOGIN, LOGIN |> show)
    let protocol = SmtpAuth.Protocol.(STARTTLS, STARTTLS |> show)

    let urlencoded ?(default = true) () =
      let open Common.Message in
      [ Field.SmtpLabel, [ label ]
      ; Field.SmtpServer, [ server ]
      ; Field.SmtpPort, [ port |> CCInt.to_string ]
      ; Field.SmtpUsername, [ username ]
      ; Field.SmtpPassword, [ password ]
      ; Field.SmtpMechanism, [ snd mechanism ]
      ; Field.SmtpProtocol, [ snd protocol ]
      ; Field.DefaultSmtpServer, [ Utils.Bool.to_string default ]
      ]
      |> CCList.map (CCPair.map_fst Field.show)
    ;;

    let create () =
      let open CCResult in
      let open Email.SmtpAuth in
      let auth =
        let* label = label |> Label.create in
        let* server = server |> Server.create in
        let* port = port |> Port.create in
        let* username =
          username |> Username.create |> CCResult.map CCOption.pure
        in
        let* password =
          password |> Password.create |> CCResult.map CCOption.pure
        in
        let mechanism = fst mechanism in
        let protocol = fst protocol in
        let default = Default.create true in
        Write.create
          ~id
          label
          server
          port
          username
          password
          mechanism
          protocol
          default
      in
      auth |> CCResult.get_exn
    ;;

    let from_write
      { SmtpAuth.Write.id
      ; label
      ; server
      ; port
      ; username
      ; mechanism
      ; protocol
      ; default
      ; _
      }
      =
      SmtpAuth.
        { id; label; server; port; username; mechanism; protocol; default }
    ;;
  end

  let tenant =
    let open Pool_tenant in
    let open CCResult in
    let* title = title |> Title.create in
    let* description = description |> Description.create >|= CCOption.return in
    let* url = url |> Url.create in
    let gtx_api_key = gtx_api_key |> GtxApiKey.of_string in
    Ok
      Write.
        { id = Id.create ()
        ; title
        ; description
        ; url
        ; database
        ; gtx_api_key
        ; styles = styles |> CCOption.return
        ; icon = icon |> CCOption.return
        ; maintenance = Maintenance.create false
        ; disabled = Disabled.create false
        ; default_language = Common.Language.En
        ; created_at = Common.CreatedAt.create ()
        ; updated_at = Common.UpdatedAt.create ()
        }
  ;;

  let full_tenant =
    let open Pool_tenant in
    let open CCResult in
    let* title = title |> Title.create in
    let* description = description |> Description.create >|= CCOption.return in
    let* url = url |> Url.create in
    let* database_label = database_label |> Pool_database.Label.create in
    let styles =
      let open Pool_common.File in
      let* name = Name.create "styles.css" in
      let* size = Size.create 20 in
      let mime_type = Mime.Css in
      Ok
        ({ id = Pool_common.Id.create ()
         ; name
         ; size
         ; mime_type
         ; created_at = Ptime_clock.now ()
         ; updated_at = Ptime_clock.now ()
         }
         |> Styles.create)
    in
    let logo_file =
      let open Pool_common.File in
      let* name = Name.create "logo.png" in
      let* size = Size.create 20 in
      let mime_type = Mime.Png in
      Ok
        { id = Pool_common.Id.create ()
        ; name
        ; size
        ; mime_type
        ; created_at = Ptime_clock.now ()
        ; updated_at = Ptime_clock.now ()
        }
    in
    let logos =
      logo_file |> CCResult.get_exn |> CCList.pure |> Logos.of_files
    in
    let partner_logo =
      logo_file |> CCResult.get_exn |> CCList.pure |> PartnerLogos.of_files
    in
    let icon = logo_file |> CCResult.get_exn |> Icon.of_file in
    Ok
      { id = Id.create ()
      ; title
      ; description
      ; url
      ; database_label
      ; styles = styles |> CCResult.get_exn |> CCOption.return
      ; icon = icon |> CCOption.return
      ; logos
      ; partner_logo
      ; maintenance = Maintenance.create false
      ; disabled = Disabled.create false
      ; default_language = Common.Language.En
      ; created_at = Common.CreatedAt.create ()
      ; updated_at = Common.UpdatedAt.create ()
      }
  ;;
end

let create_smtp_auth () =
  let open Email in
  let sys_event_id = System_event.Id.create () in
  let events =
    let open CCResult in
    let open Cqrs_command.Smtp_command.Create in
    decode (Data.Smtp.urlencoded ())
    >>= handle ~id:Data.Smtp.id ~event_id:sys_event_id None
  in
  let expected =
    Ok
      [ SmtpCreated (Data.Smtp.create ()) |> Pool_event.email
      ; System_event.(
          Job.SmtpAccountUpdated |> create ~id:sys_event_id |> created)
        |> Pool_event.system_event
      ]
  in
  Alcotest.(
    check
      (result (list Test_utils.event) Test_utils.error)
      "succeeds"
      expected
      events)
;;

let create_smtp_force_defaut () =
  let open Email in
  let sys_event_id = System_event.Id.create () in
  let events =
    let open CCResult in
    let open Cqrs_command.Smtp_command.Create in
    decode (Data.Smtp.urlencoded ~default:false ())
    >>= handle ~id:Data.Smtp.id ~event_id:sys_event_id None
  in
  let expected =
    let smtp =
      let open Email.SmtpAuth in
      Write.{ (Data.Smtp.create ()) with default = Default.create true }
    in
    Ok
      [ SmtpCreated smtp |> Pool_event.email
      ; System_event.(
          Job.SmtpAccountUpdated |> create ~id:sys_event_id |> created)
        |> Pool_event.system_event
      ]
  in
  Alcotest.(
    check
      (result (list Test_utils.event) Test_utils.error)
      "succeeds"
      expected
      events)
;;

let update_smtp_auth () =
  let open Email in
  let smtp_auth = Data.Smtp.(create () |> from_write) in
  let events =
    let open CCResult in
    let open Cqrs_command.Smtp_command.Update in
    decode (Data.Smtp.urlencoded ()) >>= handle None smtp_auth
  in
  let expected =
    let sys_event =
      let open System_event in
      Job.SmtpAccountUpdated |> create |> created |> Pool_event.system_event
    in
    Ok [ SmtpEdited smtp_auth |> Pool_event.email; sys_event ]
  in
  Alcotest.(
    check
      (result (list Test_utils.event) Test_utils.error)
      "succeeds"
      expected
      events)
;;

let[@warning "-4"] create_tenant () =
  let open Data in
  let root_events =
    let open CCResult.Infix in
    let api_key = gtx_api_key |> Pool_tenant.GtxApiKey.of_string in
    Pool_tenant_command.Create.(
      Data.urlencoded |> decode >>= handle database api_key)
  in
  let ( tenant_id
      , created_at
      , updated_at
      , (logo_id, logo_asset_id)
      , (partner_logo_id, partner_logo_asset_id)
      , database_label
      , db_added_event
      , guardian_cache_cleared_event )
    =
    (* Read Ids and timestamps to create an equal event list *)
    root_events
    |> fail_with
    |> function
    | [ Pool_event.PoolTenant
          Pool_tenant.(Created Write.{ id; created_at; updated_at; _ })
      ; Pool_event.PoolTenant
          (Pool_tenant.LogosUploaded [ partner_logo; tenant_logo ])
      ; Pool_event.Database (Database.Migrated Pool_database.{ label; _ })
      ; Pool_event.SystemEvent System_event.(Created db_added_event)
      ; Pool_event.SystemEvent System_event.(Created guardian_cache_cleared)
      ] ->
      let read_ids Pool_tenant.LogoMapping.Write.{ id; asset_id; _ } =
        id, asset_id
      in
      ( id
      , created_at
      , updated_at
      , tenant_logo |> read_ids
      , partner_logo |> read_ids
      , label
      , db_added_event.System_event.id
      , guardian_cache_cleared.System_event.id )
    | _ -> failwith "Tenant create events don't match in test."
  in
  let expected_root_events, expected_database_label =
    let open CCResult in
    let database =
      let url = database_url |> Pool_tenant.Database.Url.create |> fail_with in
      Pool_database.{ url; label = database_label }
    in
    let create =
      let* title = title |> Pool_tenant.Title.create in
      let* description =
        description |> Pool_tenant.Description.create >|= CCOption.return
      in
      let* url = url |> Pool_tenant.Url.create in
      let* default_language = default_language |> Common.Language.create in
      let gtx_api_key = Data.gtx_api_key |> Pool_tenant.GtxApiKey.of_string in
      Ok
        Pool_tenant.Write.
          { id = tenant_id
          ; title
          ; description
          ; url
          ; database
          ; gtx_api_key
          ; styles = styles |> CCOption.return
          ; icon = icon |> CCOption.return
          ; maintenance = Pool_tenant.Maintenance.create false
          ; disabled = Pool_tenant.Disabled.create false
          ; default_language
          ; created_at
          ; updated_at
          }
    in
    let logos : Pool_tenant.LogoMapping.Write.t list =
      Pool_tenant.LogoMapping.Write.
        [ { id = partner_logo_id
          ; tenant_id
          ; asset_id = partner_logo_asset_id
          ; logo_type = Pool_tenant.LogoMapping.LogoType.PartnerLogo
          }
        ; { id = logo_id
          ; tenant_id
          ; asset_id = logo_asset_id
          ; logo_type = Pool_tenant.LogoMapping.LogoType.TenantLogo
          }
        ]
    in
    let expected_root_events =
      [ Pool_tenant.Created (create |> fail_with) |> Pool_event.pool_tenant
      ; Pool_tenant.LogosUploaded logos |> Pool_event.pool_tenant
      ; Database.Migrated database |> Pool_event.database
      ; System_event.(
          Job.TenantDatabaseAdded database_label
          |> create ~id:db_added_event
          |> created)
        |> Pool_event.system_event
      ; System_event.(
          Job.GuardianCacheCleared
          |> create ~id:guardian_cache_cleared_event
          |> created)
        |> Pool_event.system_event
      ]
    in
    Ok expected_root_events, database.Pool_database.label
  in
  let () =
    Alcotest.(
      check
        (result (list Test_utils.event) Test_utils.error)
        "succeeds"
        expected_root_events
        root_events)
  in
  Alcotest.(
    check
      Test_utils.database_label
      "succeeds"
      expected_database_label
      database_label)
;;

let[@warning "-4"] update_tenant_details () =
  let open Data in
  match Data.tenant with
  | Error _ -> failwith "Failed to create tenant"
  | Ok tenant ->
    let events =
      let open CCResult.Infix in
      let open Pool_tenant_command.EditDetails in
      Data.urlencoded
      |> HttpUtils.format_request_boolean_values
           [ Common.Message.Field.(TenantDisabledFlag |> show) ]
      |> decode
      >>= handle tenant
    in
    let expected =
      let open Pool_tenant in
      let open CCResult in
      let* title = title |> Title.create in
      let* description =
        description |> Description.create >|= CCOption.return
      in
      let* url = url |> Pool_tenant.Url.create in
      let* default_language = default_language |> Common.Language.create in
      let disabled = false |> Disabled.create in
      let update : update =
        { title
        ; description
        ; url
        ; default_language
        ; styles = Some styles
        ; icon = Some icon
        ; disabled
        }
      in
      let logo_event =
        (* read logo event, as it's not value of update in this test *)
        events
        |> fail_with
        |> function
        | [ _
          ; (Pool_event.PoolTenant (Pool_tenant.LogosUploaded [ _; _ ]) as logos)
          ] -> logos
        | _ -> failwith "Tenant create events don't match in test."
      in
      Ok
        [ DetailsEdited (tenant, update) |> Pool_event.pool_tenant; logo_event ]
    in
    Alcotest.(
      check
        (result (list Test_utils.event) Test_utils.error)
        "succeeds"
        expected
        events)
;;

let update_tenant_database () =
  let open Data in
  let open CCResult.Infix in
  match Data.tenant with
  | Error _ -> failwith "Failed to create tenant"
  | Ok tenant ->
    let system_event_id = System_event.Id.create () in
    let events =
      let open Pool_tenant_command in
      let database =
        Common.Message.Field.
          [ DatabaseUrl |> show, [ database_url ]
          ; DatabaseLabel |> show, [ database_label ]
          ]
        |> decode_database
        >>= (fun { database_url; database_label } ->
              Pool_database.create database_label database_url)
        |> fail_with
      in
      UpdateDatabase.handle ~system_event_id tenant database
    in
    let expected =
      let open Pool_database in
      let open CCResult in
      let* url = database_url |> Url.create in
      let* label = database_label |> Label.create in
      let database = { url; label } in
      Ok
        [ Pool_tenant.DatabaseEdited (tenant, database)
          |> Pool_event.pool_tenant
        ; System_event.(
            Job.TenantDatabaseUpdated database.Pool_database.label
            |> create ~id:system_event_id
            |> created)
          |> Pool_event.system_event
        ]
    in
    Alcotest.(
      check
        (result (list Test_utils.event) Test_utils.error)
        "succeeds"
        expected
        events)
;;

let create_operator () =
  let open Data in
  let id = Admin.Id.create () in
  let events =
    let open CCResult.Infix in
    let open Admin_command.CreateAdmin in
    Data.urlencoded |> decode >>= handle ~id ~roles:[ `Operator, None ]
  in
  let expected =
    let open CCResult in
    let* email = email |> Pool_user.EmailAddress.create in
    let* password = password |> Pool_user.Password.create in
    let* firstname = firstname |> Pool_user.Firstname.create in
    let* lastname = lastname |> Pool_user.Lastname.create in
    let admin : Admin.create =
      { id = Some id
      ; Admin.email
      ; password
      ; firstname
      ; lastname
      ; roles = [ `Operator, None ]
      }
    in
    Ok [ Admin.Created admin |> Pool_event.admin ]
  in
  Alcotest.(
    check
      (result (list Test_utils.event) Test_utils.error)
      "succeeds"
      expected
      events)
;;
