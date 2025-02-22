open Tyxml.Html
open Component
open Input
open Pool_common
module HttpUtils = Http_utils
module Field = Message.Field

let build_experiment_path experiment =
  Format.asprintf "/admin/experiments/%s/%s" Experiment.(Id.value experiment.id)
;;

let notifications
  ?(can_update_experiment = false)
  language
  sys_languages
  message_templates
  =
  let open CCList in
  let open Pool_common in
  let open Message_template in
  message_templates
  |> filter_map (fun (label, templates) ->
    if is_empty templates || not can_update_experiment
    then None
    else
      filter
        (fun lang ->
          find_opt
            (fun { language; _ } -> Language.equal language lang)
            templates
          |> CCOption.is_none)
        sys_languages
      |> function
      | [] -> None
      | langs ->
        I18n.MissingMessageTemplates
          (Label.to_human label, CCList.map Language.show langs)
        |> Utils.hint_to_string language
        |> txt
        |> pure
        |> Notification.notification language `Warning
        |> CCOption.return)
  |> function
  | [] -> txt ""
  | notifications -> div ~a:[ a_class [ "stack" ] ] notifications
;;

let message_templates_html
  ?(can_update_experiment = false)
  language
  csrf
  experiment_path
  sys_languages
  message_templates
  =
  let open Message_template in
  let buttons =
    let build_button label =
      experiment_path Label.(prefixed_human_url label)
      |> Page_admin_message_template.build_add_button label
    in
    message_templates
    |> CCList.filter_map (fun (label, templates) ->
      if CCList.is_empty (filter_languages sys_languages templates)
      then None
      else label |> build_button |> CCOption.pure)
    |> div ~a:[ a_class [ "flexrow"; "flex-gap"; "justify-end" ] ]
    |> fun buttons -> if can_update_experiment then Some buttons else None
  in
  let build_path append =
    CCFun.(prefixed_template_url ~append %> experiment_path)
  in
  let edit_path = build_path "edit" in
  let delete_path = build_path "delete", csrf in
  Page_admin_message_template.table
    ?buttons
    ~can_update_experiment
    ~delete_path
    language
    (CCList.flat_map (fun (_, templates) -> templates) message_templates)
    edit_path
;;

let index Pool_context.{ language; _ } experiment_list =
  let experiment_table experiments =
    let thead =
      Message.
        [ Field.Title |> Table.field_to_txt language
        ; Field.PublicTitle |> Table.field_to_txt language
        ; link_as_button
            ~style:`Success
            ~icon:Icon.Add
            ~control:(language, Message.(Add (Some Field.Experiment)))
            "/admin/experiments/create"
        ]
    in
    let rows =
      CCList.map
        (fun (experiment : Experiment.t) ->
          let open Experiment in
          [ txt (Title.value experiment.title)
          ; txt (PublicTitle.value experiment.public_title)
          ; Format.asprintf
              "/admin/experiments/%s"
              (experiment.id |> Experiment.Id.value)
            |> link_as_button ~icon:Icon.Eye
          ])
        experiments
    in
    Table.horizontal_table `Striped ~align_last_end:true ~thead rows
  in
  div
    ~a:[ a_class [ "trim"; "safety-margin" ] ]
    [ h1
        ~a:[ a_class [ "heading-1" ] ]
        [ txt (Utils.text_to_string language I18n.ExperimentListTitle) ]
    ; Component.List.create
        language
        experiment_table
        Experiment.sortable_by
        Experiment.searchable_by
        experiment_list
    ]
;;

let experiment_form
  ?experiment
  Pool_context.{ language; csrf; _ }
  contact_persons
  organisational_units
  smtp_auth_list
  default_email_reminder_lead_time
  default_text_msg_reminder_lead_time
  flash_fetcher
  =
  let open Experiment in
  let action =
    match experiment with
    | None -> "/admin/experiments"
    | Some experiment ->
      Format.asprintf
        "/admin/experiments/%s"
        (experiment.id |> Experiment.Id.value)
  in
  let checkbox_element ?help ?(default = false) field fnc =
    checkbox_element
      language
      ?help
      field
      ~value:(experiment |> CCOption.map_or ~default fnc)
      ~flash_fetcher
  in
  let value = CCFun.flip (CCOption.map_or ~default:"") experiment in
  let experiment_type_select =
    let open ExperimentType in
    selector
      language
      Field.ExperimentType
      show
      all
      (CCOption.bind experiment (fun (e : Experiment.t) -> e.experiment_type))
      ~add_empty:true
      ~flash_fetcher
      ()
  in
  let lead_time_group field get_value default_value =
    div
      [ timespan_picker
          language
          field
          ~help:
            [ I18n.TimeSpanPickerHint
            ; I18n.DefaultReminderLeadTime
                (default_value |> Reminder.LeadTime.value)
            ]
          ?value:CCOption.(bind experiment get_value)
          ~flash_fetcher
      ]
  in
  form
    ~a:
      [ a_method `Post
      ; a_action (Sihl.Web.externalize_path action)
      ; a_class [ "stack" ]
      ; a_user_data "detect-unsaved-changes" ""
      ]
    [ csrf_element csrf ()
    ; div
        ~a:[ a_class [ "stack-lg" ] ]
        [ div
            ~a:[ a_class [ "grid-col-2" ] ]
            [ input_element
                language
                `Text
                Field.Title
                ~value:(value title_value)
                ~required:true
                ~flash_fetcher
            ; input_element
                language
                `Text
                Field.PublicTitle
                ~value:(value public_title_value)
                ~required:(CCOption.is_some experiment)
                ~flash_fetcher
            ; textarea_element
                language
                Field.Description
                ?value:
                  (CCOption.bind experiment (fun { description; _ } ->
                     description |> CCOption.map Description.value))
                ~flash_fetcher
            ; experiment_type_select
            ; input_element
                language
                `Text
                Field.CostCenter
                ?value:
                  (CCOption.bind experiment (fun e ->
                     e.cost_center |> CCOption.map CostCenter.value))
                ~flash_fetcher
            ; organisational_units_selector
                language
                organisational_units
                (CCOption.bind experiment (fun ex -> ex.organisational_unit))
            ]
        ; div
            [ h3
                ~a:[ a_class [ "heading-3" ] ]
                [ txt
                    (Utils.text_to_string
                       language
                       I18n.ExperimentMessagingSubtitle)
                ]
            ; div
                ~a:[ a_class [ "grid-col-2" ] ]
                [ admin_select
                    language
                    contact_persons
                    (CCOption.bind experiment (fun exp -> exp.contact_person_id))
                    Field.ContactPerson
                    ~help:Pool_common.I18n.ExperimentContactPerson
                    ()
                ; selector
                    language
                    Field.Smtp
                    Email.SmtpAuth.(fun ({ id; _ } : t) -> Id.value id)
                    smtp_auth_list
                    CCOption.(
                      experiment
                      >>= fun { smtp_auth_id; _ } ->
                      smtp_auth_id
                      >>= Email.SmtpAuth.(
                            fun smtp_auth_id ->
                              CCList.find_opt
                                (fun ({ id; _ } : t) ->
                                  Id.equal id smtp_auth_id)
                                smtp_auth_list))
                    ~option_formatter:
                      Email.SmtpAuth.(fun { label; _ } -> Label.value label)
                    ~flash_fetcher
                    ~add_empty:true
                    ()
                ]
            ]
        ; div
            ~a:[ a_class [ "stack" ] ]
            [ checkbox_element
                ~help:I18n.DirectRegistrationDisbled
                Field.DirectRegistrationDisabled
                direct_registration_disabled_value
            ; checkbox_element
                ~help:I18n.RegistrationDisabled
                Field.RegistrationDisabled
                registration_disabled_value
            ; checkbox_element
                ~help:I18n.AllowUninvitedSignup
                Field.AllowUninvitedSignup
                allow_uninvited_signup_value
            ; checkbox_element
                ~help:I18n.ExternalDataRequired
                Field.ExternalDataRequired
                external_data_required_value
            ; checkbox_element
                Field.ShowExteralDataIdLinks
                show_external_data_id_links_value
            ]
        ; div
            [ h3
                ~a:[ a_class [ "heading-3" ] ]
                [ txt (Utils.text_to_string language I18n.SessionReminder) ]
            ; div
                ~a:[ a_class [ "stack" ] ]
                [ p
                    [ txt
                        (Utils.text_to_string
                           language
                           I18n.ExperimentSessionReminderHint)
                    ]
                ; div
                    ~a:[ a_class [ "grid-col-2" ] ]
                    [ lead_time_group
                        Field.EmailLeadTime
                        email_session_reminder_lead_time_value
                        default_email_reminder_lead_time
                    ; lead_time_group
                        Field.TextMessageLeadTime
                        text_message_session_reminder_lead_time_value
                        default_text_msg_reminder_lead_time
                    ]
                ]
            ]
        ]
    ; div
        ~a:[ a_class [ "flexrow" ] ]
        [ div
            ~a:[ a_class [ "push"; "flexrow"; "flex-gap-lg" ] ]
            [ reset_form_button language
            ; submit_element
                language
                Message.(
                  let field = Some Field.Experiment in
                  match experiment with
                  | None -> Create field
                  | Some _ -> Update field)
                ~submit_type:`Primary
                ()
            ]
        ]
    ]
;;

let create
  (Pool_context.{ language; _ } as context)
  organisational_units
  default_email_reminder_lead_time
  default_text_msg_reminder_lead_time
  contact_persons
  smtp_auth_list
  flash_fetcher
  =
  div
    ~a:[ a_class [ "trim"; "safety-margin"; "stack" ] ]
    [ h1
        [ txt
            (Utils.control_to_string
               language
               Message.(Create (Some Field.Experiment)))
        ]
    ; experiment_form
        context
        contact_persons
        organisational_units
        smtp_auth_list
        default_email_reminder_lead_time
        default_text_msg_reminder_lead_time
        flash_fetcher
    ]
;;

let edit
  ?(allowed_to_assign = false)
  experiment
  ({ Pool_context.language; csrf; query_language; _ } as context)
  default_email_reminder_lead_time
  default_text_msg_reminder_lead_time
  contact_persons
  organisational_units
  smtp_auth_list
  (available_tags, current_tags)
  (available_participation_tags, current_participation_tags)
  flash_fetcher
  =
  let form =
    experiment_form
      ~experiment
      context
      contact_persons
      organisational_units
      smtp_auth_list
      default_email_reminder_lead_time
      default_text_msg_reminder_lead_time
      flash_fetcher
  in
  let tags_html (available, current) field =
    if allowed_to_assign
    then (
      let remove_action tag =
        Format.asprintf
          "%s/%s/remove"
          Field.(field |> human_url)
          Tags.(Id.value tag.Tags.id)
        |> build_experiment_path experiment
      in
      let assign_action =
        Http_utils.externalize_path_with_lang
          query_language
          (Format.asprintf "%s/assign" Field.(field |> human_url)
           |> build_experiment_path experiment)
      in
      div
        ~a:[ a_class [ "switcher-lg"; "flex-gap" ] ]
        [ Tag.add_tags_form context ~existing:current available assign_action
        ; Component.Tag.tag_list
            language
            ~remove_action:(remove_action, csrf)
            ~title:Pool_common.I18n.SelectedTags
            current
        ])
    else txt ""
  in
  let tags =
    div
      ~a:[ a_class [ "stack" ] ]
      [ h2
          ~a:[ a_class [ "heading-2" ] ]
          [ Utils.nav_link_to_string language I18n.Tags |> txt ]
      ; tags_html (available_tags, current_tags) Field.Tag
      ; div
          [ h3
              ~a:[ a_class [ "heading-3" ] ]
              [ Utils.field_to_string language Field.ParticipationTag
                |> String.capitalize_ascii
                |> txt
              ]
          ; p [ Utils.hint_to_string language I18n.ParticipationTags |> txt ]
          ; tags_html
              (available_participation_tags, current_participation_tags)
              Field.ParticipationTag
          ]
      ]
  in
  [ div ~a:[ a_class [ "stack-lg" ] ] [ form; tags ] ]
  |> Layout.Experiment.(
       create
         context
         (Control Message.(Edit (Some Field.Experiment)))
         experiment)
;;

let detail
  ({ Experiment.id; _ } as experiment)
  session_count
  message_templates
  sys_languages
  contact_person
  smtp_account
  tags
  participation_tags
  ({ Pool_context.language; csrf; guardian; _ } as context)
  =
  let experiment_path = build_experiment_path experiment in
  let can_update_experiment =
    Guard.PermissionOnTarget.validate
      (Experiment.Guard.Access.update_permission_on_target id)
      guardian
  in
  let notifications =
    notifications
      ~can_update_experiment
      language
      sys_languages
      message_templates
  in
  let delete_form =
    match session_count > 0 with
    | true ->
      div
        ~a:[ a_class [ "flexrow"; "flex-gap"; "flexcolumn-mobile" ] ]
        [ submit_element
            language
            Message.(Delete (Some Field.Experiment))
            ~submit_type:`Disabled
            ~has_icon:Icon.TrashOutline
            ~classnames:[ "small" ]
            ()
        ; div
            ~a:[ a_class [ "grow" ] ]
            [ txt
                (Message.ExperimentSessionCountNotZero
                 |> Utils.error_to_string language)
            ]
        ]
    | false ->
      div
        ~a:[ a_class [ "flexrow"; "flex-gap"; "flexcolumn-mobile" ] ]
        [ form
            ~a:
              [ a_method `Post
              ; a_action
                  (Sihl.Web.externalize_path
                     (Format.asprintf
                        "/admin/experiments/%s/delete"
                        (experiment.Experiment.id |> Experiment.Id.value)))
              ; a_user_data
                  "confirmable"
                  (Utils.confirmable_to_string language I18n.DeleteExperiment)
              ]
            [ csrf_element csrf ()
            ; submit_element
                language
                Message.(Delete (Some Field.Experiment))
                ~classnames:[ "small" ]
                ~submit_type:`Error
                ~has_icon:Icon.TrashOutline
                ()
            ]
        ]
  in
  let reset_invitation_form =
    let open Experiment in
    let last_reset_at =
      match experiment.invitation_reset_at with
      | None -> txt ""
      | Some reset_at ->
        span
          [ Pool_common.(
              Utils.hint_to_string
                language
                (I18n.ResetInvitationsLastReset
                   (InvitationResetAt.value reset_at))
              |> Unsafe.data)
          ]
    in
    div
      ~a:[ a_class [ "flexrow"; "flex-gap"; "flexcolumn-mobile" ] ]
      [ form
          ~a:
            [ a_method `Post
            ; a_action
                (Sihl.Web.externalize_path
                   (Format.asprintf
                      "/admin/experiments/%s/reset-invitations"
                      (experiment.Experiment.id |> Experiment.Id.value)))
            ; a_user_data
                "confirmable"
                (Utils.confirmable_to_string language I18n.ResetInvitations)
            ]
          [ csrf_element csrf ()
          ; submit_element
              language
              Message.(Reset (Some Field.Invitations))
              ~classnames:[ "small" ]
              ~submit_type:`Primary
              ~has_icon:Icon.RefreshOutline
              ()
          ]
      ; div
          ~a:[ a_class [ "grow"; "flexcolumn" ] ]
          [ span
              [ txt
                  Pool_common.(
                    Utils.hint_to_string language I18n.ResetInvitations)
              ]
          ; last_reset_at
          ]
      ]
  in
  let setting =
    if can_update_experiment
    then
      [ div
          ~a:[ a_class [ "stack-md" ] ]
          [ h2
              ~a:[ a_class [ "heading-2" ] ]
              [ txt
                  Pool_common.(
                    Utils.field_to_string language Message.Field.Settings
                    |> CCString.capitalize_ascii)
              ]
          ; reset_invitation_form
          ; delete_form
          ]
      ]
    else []
  in
  let bool_to_string = Utils.bool_to_string language in
  let open Experiment in
  let vertical_table =
    Table.vertical_table
      ~classnames:[ "layout-fixed" ]
      ~align_top:true
      `Striped
      language
  in
  let html =
    let experiment_table =
      let boolean_value fnc = fnc experiment |> bool_to_string |> txt in
      Message.
        [ Field.PublicTitle, experiment.public_title |> PublicTitle.value |> txt
        ; ( Field.ExperimentType
          , experiment.experiment_type
            |> CCOption.map_or ~default:"" ExperimentType.show
            |> txt )
        ; ( Field.Description
          , experiment.description
            |> CCOption.map_or ~default:(txt "") (fun desc ->
              desc |> Description.value |> HttpUtils.add_line_breaks) )
        ; ( Field.CostCenter
          , experiment.cost_center
            |> CCOption.map_or ~default:"" CostCenter.value
            |> txt )
        ; ( Field.OrganisationalUnit
          , experiment.organisational_unit
            |> CCOption.map_or
                 ~default:""
                 Organisational_unit.(fun ou -> ou.name |> Name.value)
            |> txt )
        ; ( Field.ContactPerson
          , contact_person |> CCOption.map_or ~default:"" Admin.full_name |> txt
          )
        ; ( Field.Smtp
          , smtp_account
            |> CCOption.map_or
                 ~default:""
                 Email.SmtpAuth.(fun auth -> auth.label |> Label.value)
            |> txt )
        ; ( Field.DirectRegistrationDisabled
          , direct_registration_disabled_value |> boolean_value )
        ; ( Field.RegistrationDisabled
          , registration_disabled_value |> boolean_value )
        ; ( Field.AllowUninvitedSignup
          , allow_uninvited_signup_value |> boolean_value )
        ; ( Field.ExternalDataRequired
          , external_data_required_value |> boolean_value )
        ; ( Field.ShowExteralDataIdLinks
          , show_external_data_id_links_value |> boolean_value )
        ; ( Field.ExperimentEmailReminderLeadTime
          , email_session_reminder_lead_time_value experiment
            |> CCOption.map_or
                 ~default:"-"
                 Pool_common.Utils.Time.formatted_timespan
            |> txt )
        ; ( Field.ExperimentTextMessageReminderLeadTime
          , text_message_session_reminder_lead_time_value experiment
            |> CCOption.map_or
                 ~default:"-"
                 Pool_common.Utils.Time.formatted_timespan
            |> txt )
        ; ( Field.InvitationResetAt
          , experiment.invitation_reset_at
            |> CCOption.map_or ~default:"-" InvitationResetAt.to_human
            |> txt )
        ]
      |> vertical_table
    in
    let message_template =
      div
        [ h3
            ~a:[ a_class [ "heading-3" ] ]
            [ txt
                Pool_common.(
                  Utils.nav_link_to_string language I18n.MessageTemplates)
            ]
        ; message_templates_html
            ~can_update_experiment
            language
            csrf
            experiment_path
            sys_languages
            message_templates
        ]
    in
    let tag_overview =
      let build (title, tags) =
        div
          [ h3
              ~a:[ a_class [ "heading-3" ] ]
              Pool_common.[ Utils.nav_link_to_string language title |> txt ]
          ; Component.Tag.tag_list language tags
          ]
      in
      Pool_common.I18n.[ Tags, tags; ParticipationTags, participation_tags ]
      |> CCList.map build
      |> div ~a:[ a_class [ "switcher"; "flex-gap" ] ]
    in
    [ div
        ~a:[ a_class [ "stack-lg" ] ]
        ([ notifications; experiment_table; tag_overview; message_template ]
         @ setting)
    ]
  in
  let edit_button =
    if can_update_experiment
    then
      link_as_button
        ~icon:Icon.Create
        ~classnames:[ "small" ]
        ~control:(language, Message.(Edit (Some Field.Experiment)))
        (Format.asprintf
           "/admin/experiments/%s/edit"
           (experiment.id |> Experiment.Id.value))
      |> CCOption.some
    else None
  in
  Layout.Experiment.(
    create
      ~active_navigation:I18n.Overview
      ?buttons:edit_button
      context
      (NavLink I18n.Overview)
      experiment
      html)
;;

let invitations
  experiment
  key_list
  template_list
  query_experiments
  query_tags
  filtered_contacts
  ({ Pool_context.language; _ } as context)
  =
  [ div
      ~a:[ a_class [ "stack" ] ]
      [ p
          [ a
              ~a:
                [ a_href
                    (experiment.Experiment.id
                     |> Experiment.Id.value
                     |> Format.asprintf "admin/experiments/%s/invitations/sent"
                     |> Sihl.Web.externalize_path)
                ]
              [ txt (Utils.text_to_string language I18n.SentInvitations) ]
          ]
      ; Page_admin_invitations.Partials.send_invitation
          context
          experiment
          key_list
          template_list
          query_experiments
          query_tags
          filtered_contacts
      ]
  ]
  |> Layout.Experiment.(
       create
         ~active_navigation:I18n.Invitations
         context
         (NavLink I18n.Invitations)
         experiment)
;;

let sent_invitations
  (Pool_context.{ language; _ } as context)
  experiment
  invitations
  statistics
  =
  let invitation_table =
    Page_admin_invitations.Partials.list context experiment
  in
  div
    ~a:[ a_class [ "stack-lg" ] ]
    [ div
        ~a:[ a_class [ "grid-col-2" ] ]
        [ div
            ~a:[ a_class [ "stack-xs"; "inset"; "bg-grey-light"; "border" ] ]
            [ Page_admin_invitations.Partials.statistics language statistics ]
        ]
    ; Component.List.create
        language
        invitation_table
        Invitation.sortable_by
        Invitation.searchable_by
        invitations
    ]
  |> CCList.return
  |> Layout.Experiment.(
       create
         ~active_navigation:I18n.Invitations
         context
         (I18n I18n.SentInvitations)
         experiment)
;;

let waiting_list
  ({ Waiting_list.ExperimentList.experiment; waiting_list_entries }, query)
  ({ Pool_context.language; _ } as context)
  =
  let open Waiting_list.ExperimentList in
  let waiting_list_table waiting_list_entries =
    let thead =
      (Field.[ Name; Email; CellPhone; SignedUpAt; AdminComment ]
       |> Table.fields_to_txt language)
      @ [ txt "" ]
    in
    let rows =
      let open CCOption in
      CCList.map
        Contact.Preview.(
          fun entry ->
            [ txt (fullname entry.contact)
            ; txt (email_address entry.contact |> Pool_user.EmailAddress.value)
            ; txt
                (entry.contact.cell_phone
                 |> map_or ~default:"" Pool_user.CellPhone.value)
            ; txt
                (entry.created_at
                 |> CreatedAt.value
                 |> Utils.Time.formatted_date_time)
            ; entry.admin_comment
              |> map_or ~default:"" Waiting_list.AdminComment.value
              |> HttpUtils.first_n_characters
              |> HttpUtils.add_line_breaks
            ; Format.asprintf
                "/admin/experiments/%s/waiting-list/%s"
                (experiment.Experiment.id |> Experiment.Id.value)
                (entry.id |> Id.value)
              |> edit_link
            ])
        waiting_list_entries
    in
    Table.horizontal_table
      `Striped
      ~align_top:true
      ~align_last_end:true
      ~thead
      rows
  in
  Component.List.create
    language
    waiting_list_table
    Waiting_list.sortable_by
    Waiting_list.searchable_by
    (waiting_list_entries, query)
  |> CCList.return
  |> Layout.Experiment.(
       create
         ~active_navigation:I18n.WaitingList
         ~hint:I18n.ExperimentWaitingList
         context
         (NavLink I18n.WaitingList)
         experiment)
;;

let users role experiment applicable_admins currently_assigned context =
  let base_url field admin =
    Format.asprintf
      "/admin/experiments/%s/%s/%s"
      Experiment.(experiment.id |> Id.value)
      (Field.show field)
      (Admin.id admin |> Admin.Id.value)
    |> Sihl.Web.externalize_path
  in
  let field =
    let open Message in
    match role with
    | `Assistants -> Field.Assistants
    | `Experimenter -> Field.Experimenter
  in
  Page_admin_experiment_users.role_assignment
    (base_url field)
    field
    context
    ~assign:"assign"
    ~unassign:"unassign"
    ~applicable:applicable_admins
    ~current:currently_assigned
  |> CCList.return
  |> Layout.Experiment.(
       create
         ~active_navigation:(I18n.Field field)
         context
         (NavLink (I18n.Field field))
         experiment)
;;

let message_template_form
  ({ Pool_context.language; _ } as context)
  tenant
  experiment
  languages
  label
  template
  flash_fetcher
  =
  let open Message_template in
  let action, input =
    let open Page_admin_message_template in
    let path =
      Format.asprintf
        "/admin/experiments/%s/%s"
        Experiment.(Id.value experiment.Experiment.id)
    in
    match template with
    | None -> path (Label.prefixed_human_url label), New label
    | Some template -> path (prefixed_template_url template), Existing template
  in
  let title =
    let open Pool_common in
    let open Layout.Experiment in
    (match template with
     | None -> Message.(Create None)
     | Some _ -> Message.(Edit None))
    |> fun control ->
    Text
      (Format.asprintf
         "%s %s"
         (control |> Utils.control_to_string language)
         (label |> Label.to_human |> CCString.lowercase_ascii))
  in
  let text_elements =
    Component.MessageTextElements.message_template_help
      ~experiment
      language
      tenant
      label
  in
  Page_admin_message_template.template_form
    context
    ?languages
    ~text_elements
    input
    action
    flash_fetcher
  |> CCList.return
  |> Layout.Experiment.create context title experiment
;;
