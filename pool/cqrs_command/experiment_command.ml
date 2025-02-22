module BaseGuard = Guard
open Experiment
module Conformist = Pool_common.Utils.PoolConformist

let src = Logs.Src.create "experiment_command.cqrs"
let to_actor = CCFun.(Admin.id %> BaseGuard.Uuid.actor_of Admin.Id.value)
let to_target { id; _ } = BaseGuard.Uuid.target_of Id.value id

let to_role (admin, role, target_uuid) =
  BaseGuard.ActorRole.create ?target_uuid admin role
;;

let default_command
  title
  public_title
  description
  cost_center
  direct_registration_disabled
  registration_disabled
  allow_uninvited_signup
  external_data_required
  show_external_data_id_links
  experiment_type
  email_session_reminder_lead_time
  text_message_session_reminder_lead_time
  =
  { title
  ; public_title
  ; description
  ; cost_center
  ; direct_registration_disabled
  ; registration_disabled
  ; allow_uninvited_signup
  ; external_data_required
  ; show_external_data_id_links
  ; experiment_type
  ; email_session_reminder_lead_time
  ; text_message_session_reminder_lead_time
  }
;;

let create_command
  title
  public_title
  description
  cost_center
  direct_registration_disabled
  registration_disabled
  allow_uninvited_signup
  external_data_required
  show_external_data_id_links
  experiment_type
  email_session_reminder_lead_time
  text_message_session_reminder_lead_time
  =
  default_command
    title
    (CCOption.value ~default:PublicTitle.placeholder public_title)
    description
    cost_center
    direct_registration_disabled
    registration_disabled
    allow_uninvited_signup
    external_data_required
    show_external_data_id_links
    experiment_type
    email_session_reminder_lead_time
    text_message_session_reminder_lead_time
;;

let update_schema command =
  let open Pool_common in
  Utils.PoolConformist.(
    make
      Field.
        [ Title.schema ()
        ; PublicTitle.schema ()
        ; Conformist.optional @@ Description.schema ()
        ; Conformist.optional @@ CostCenter.schema ()
        ; DirectRegistrationDisabled.schema ()
        ; RegistrationDisabled.schema ()
        ; AllowUninvitedSignup.schema ()
        ; ExternalDataRequired.schema ()
        ; ShowExternalDataIdLinks.schema ()
        ; Conformist.optional @@ ExperimentType.schema ()
        ; Conformist.optional
          @@ Reminder.LeadTime.schema ~field:Message.Field.EmailLeadTime ()
        ; Conformist.optional
          @@ Reminder.LeadTime.schema
               ~field:Message.Field.TextMessageLeadTime
               ()
        ]
      command)
;;

let create_schema command =
  let open Pool_common in
  Utils.PoolConformist.(
    make
      Field.
        [ Title.schema ()
        ; Conformist.optional @@ PublicTitle.schema ()
        ; Conformist.optional @@ Description.schema ()
        ; Conformist.optional @@ CostCenter.schema ()
        ; DirectRegistrationDisabled.schema ()
        ; RegistrationDisabled.schema ()
        ; AllowUninvitedSignup.schema ()
        ; ExternalDataRequired.schema ()
        ; ShowExternalDataIdLinks.schema ()
        ; Conformist.optional @@ ExperimentType.schema ()
        ; Conformist.optional
          @@ Reminder.LeadTime.schema ~field:Message.Field.EmailLeadTime ()
        ; Conformist.optional
          @@ Reminder.LeadTime.schema
               ~field:Message.Field.TextMessageLeadTime
               ()
        ]
      command)
;;

type update_role =
  { admin : Admin.t
  ; experiment : Experiment.t
  }

module Create : sig
  include Common.CommandSig with type t = create

  val handle
    :  ?tags:Logs.Tag.set
    -> ?contact_person:Admin.t
    -> ?organisational_unit:Organisational_unit.t
    -> ?smtp_auth:Email.SmtpAuth.t
    -> t
    -> (Pool_event.t list, Pool_common.Message.error) result

  val decode
    :  (string * string list) list
    -> (t, Pool_common.Message.error) result
end = struct
  type t = create

  let handle
    ?(tags = Logs.Tag.empty)
    ?contact_person
    ?organisational_unit
    ?smtp_auth
    ({ cost_center
     ; description
     ; email_session_reminder_lead_time
     ; experiment_type
     ; text_message_session_reminder_lead_time
     ; _
     } as command :
      t)
    =
    Logs.info ~src (fun m -> m "Handle command Create" ~tags);
    let open CCResult in
    let* experiment =
      Experiment.create
        ?contact_person_id:(contact_person |> CCOption.map Admin.id)
        ?cost_center
        ?description
        ?email_session_reminder_lead_time
        ?experiment_type
        ?organisational_unit
        ?smtp_auth_id:
          (smtp_auth |> CCOption.map Email.SmtpAuth.(fun ({ id; _ } : t) -> id))
        ?text_message_session_reminder_lead_time
        command.title
        command.public_title
        command.direct_registration_disabled
        command.registration_disabled
        command.allow_uninvited_signup
        command.external_data_required
        command.show_external_data_id_links
    in
    Ok [ Experiment.Created experiment |> Pool_event.experiment ]
  ;;

  let decode data =
    Conformist.decode_and_validate (create_schema create_command) data
    |> CCResult.map_err Pool_common.Message.to_conformist_error
  ;;

  let effects = Experiment.Guard.Access.create
end

module Update : sig
  include Common.CommandSig with type t = create

  val handle
    :  ?tags:Logs.Tag.set
    -> Experiment.t
    -> Admin.t option
    -> Organisational_unit.t option
    -> Email.SmtpAuth.t option
    -> t
    -> (Pool_event.t list, Pool_common.Message.error) result

  val decode
    :  (string * string list) list
    -> (t, Pool_common.Message.error) result

  val effects : Id.t -> BaseGuard.ValidationSet.t
end = struct
  type t = create

  let handle
    ?(tags = Logs.Tag.empty)
    experiment
    contact_person
    organisational_unit
    smtp
    (command : t)
    =
    Logs.info ~src (fun m -> m "Handle command Update" ~tags);
    let open CCResult in
    let experiment =
      Experiment.
        { experiment with
          title = command.title
        ; public_title = command.public_title
        ; description = command.description
        ; cost_center = command.cost_center
        ; organisational_unit
        ; contact_person_id = CCOption.map Admin.id contact_person
        ; smtp_auth_id =
            CCOption.map Email.SmtpAuth.(fun ({ id; _ } : t) -> id) smtp
        ; direct_registration_disabled = command.direct_registration_disabled
        ; registration_disabled = command.registration_disabled
        ; allow_uninvited_signup = command.allow_uninvited_signup
        ; external_data_required = command.external_data_required
        ; show_external_data_id_links = command.show_external_data_id_links
        ; experiment_type = command.experiment_type
        ; email_session_reminder_lead_time =
            command.email_session_reminder_lead_time
        ; text_message_session_reminder_lead_time =
            command.text_message_session_reminder_lead_time
        }
    in
    Ok [ Experiment.Updated experiment |> Pool_event.experiment ]
  ;;

  let decode data =
    Conformist.decode_and_validate (update_schema default_command) data
    |> CCResult.map_err Pool_common.Message.to_conformist_error
  ;;

  let effects id = Experiment.Guard.Access.update id
end

module ResetInvitations : sig
  include Common.CommandSig with type t = Experiment.t

  val effects : Id.t -> BaseGuard.ValidationSet.t
end = struct
  type t = Experiment.t

  let handle ?(tags = Logs.Tag.empty) (experiment : t) =
    Logs.info ~src (fun m -> m "Handle command ResetInvitations" ~tags);
    Ok [ Experiment.ResetInvitations experiment |> Pool_event.experiment ]
  ;;

  let effects id = Experiment.Guard.Access.update id
end

module Delete : sig
  include Common.CommandSig

  type t =
    { experiment : Experiment.t
    ; session_count : int
    ; mailings : Mailing.t list
    ; assistants : Admin.t list
    ; experimenters : Admin.t list
    ; templates : Message_template.t list
    }

  val handle
    :  ?tags:Logs.Tag.set
    -> ?system_event_id:System_event.Id.t
    -> t
    -> (Pool_event.t list, Pool_common.Message.error) result

  val effects : Id.t -> BaseGuard.ValidationSet.t
end = struct
  (* Only when no sessions added *)

  type t =
    { experiment : Experiment.t
    ; session_count : int
    ; mailings : Mailing.t list
    ; assistants : Admin.t list
    ; experimenters : Admin.t list
    ; templates : Message_template.t list
    }

  let handle
    ?(tags = Logs.Tag.empty)
    ?system_event_id
    { experiment
    ; session_count
    ; mailings
    ; experimenters
    ; assistants
    ; templates
    }
    =
    let open CCFun in
    let open CCResult in
    Logs.info ~src (fun m -> m "Handle command Delete" ~tags);
    let* () =
      session_count
      > 0
      |> Utils.bool_to_result_not
           Pool_common.Message.ExperimentSessionCountNotZero
    in
    let delete_mailing = Mailing.deleted %> Pool_event.mailing in
    let revoke_experimenter admin =
      BaseGuard.RolesRevoked
        [ (admin |> to_actor, `Experimenter, Some (experiment |> to_target))
          |> to_role
        ]
      |> Pool_event.guard
    in
    let revoke_assistant admin =
      BaseGuard.RolesRevoked
        [ (admin |> to_actor, `Assistant, Some (experiment |> to_target))
          |> to_role
        ]
      |> Pool_event.guard
    in
    let filter_events =
      CCOption.map_or
        ~default:[]
        (Filter.deleted %> Pool_event.filter %> CCList.return)
    in
    let delete_template =
      Message_template.deleted %> Pool_event.message_template
    in
    Ok
      ([ Experiment.Deleted experiment.Experiment.id |> Pool_event.experiment ]
       @ (experiment.Experiment.filter |> filter_events)
       @ (mailings |> CCList.map delete_mailing)
       @ (experimenters |> CCList.map revoke_experimenter)
       @ (assistants |> CCList.map revoke_assistant)
       @ (templates |> CCList.map delete_template)
       @ [ Common.guardian_cache_cleared_event ?id:system_event_id () ])
  ;;

  let effects id = Experiment.Guard.Access.delete id
end

module AssignAssistant : sig
  include Common.CommandSig with type t = update_role

  val effects : Id.t -> BaseGuard.ValidationSet.t
end = struct
  type t = update_role

  let handle ?(tags = Logs.Tag.empty) { admin; experiment } =
    Logs.info ~src (fun m -> m "Handle command AssignAssistant" ~tags);
    Ok
      [ BaseGuard.RolesGranted
          [ (admin |> to_actor, `Assistant, Some (experiment |> to_target))
            |> to_role
          ]
        |> Pool_event.guard
      ; Common.guardian_cache_cleared_event ()
      ]
  ;;

  let effects id = Experiment.Guard.Access.update id
end

module UnassignAssistant : sig
  include Common.CommandSig with type t = update_role

  val effects : Id.t -> BaseGuard.ValidationSet.t
end = struct
  type t = update_role

  let handle ?(tags = Logs.Tag.empty) { admin; experiment } =
    Logs.info ~src (fun m -> m "Handle command UnassignAssistant" ~tags);
    Ok
      [ BaseGuard.RolesRevoked
          [ (admin |> to_actor, `Assistant, Some (experiment |> to_target))
            |> to_role
          ]
        |> Pool_event.guard
      ; Common.guardian_cache_cleared_event ()
      ]
  ;;

  let effects id = Experiment.Guard.Access.update id
end

module AssignExperimenter : sig
  include Common.CommandSig with type t = update_role

  val effects : Id.t -> BaseGuard.ValidationSet.t
end = struct
  type t = update_role

  let handle ?(tags = Logs.Tag.empty) { admin; experiment } =
    Logs.info ~src (fun m -> m "Handle command AssignExperimenter" ~tags);
    Ok
      [ BaseGuard.RolesGranted
          [ (admin |> to_actor, `Experimenter, Some (experiment |> to_target))
            |> to_role
          ]
        |> Pool_event.guard
      ; Common.guardian_cache_cleared_event ()
      ]
  ;;

  let effects id = Experiment.Guard.Access.update id
end

module UnassignExperimenter : sig
  include Common.CommandSig with type t = update_role

  val effects : Id.t -> BaseGuard.ValidationSet.t
end = struct
  type t = update_role

  let handle ?(tags = Logs.Tag.empty) { admin; experiment } =
    Logs.info ~src (fun m -> m "Handle command UnassignExperimenter" ~tags);
    Ok
      [ BaseGuard.RolesRevoked
          [ (admin |> to_actor, `Experimenter, Some (experiment |> to_target))
            |> to_role
          ]
        |> Pool_event.guard
      ; Common.guardian_cache_cleared_event ()
      ]
  ;;

  let effects id = Experiment.Guard.Access.update id
end

module CreateFilter : sig
  include Common.CommandSig with type t = Filter.query

  val handle
    :  ?tags:Logs.Tag.set
    -> Experiment.t
    -> Filter.Key.human list
    -> Filter.t list
    -> t
    -> (Pool_event.t list, Pool_common.Message.error) result

  val effects : Id.t -> BaseGuard.ValidationSet.t
end = struct
  type t = Filter.query

  let handle ?(tags = Logs.Tag.empty) experiment key_list template_list query =
    Logs.info ~src (fun m -> m "Handle command CreateFilter" ~tags);
    let open CCResult in
    let* query = Filter.validate_query key_list template_list query in
    let id = Pool_common.Id.create () in
    let filter = Filter.create ~id None query in
    let experiment = Experiment.{ experiment with filter = Some filter } in
    Ok
      [ Filter.Created filter |> Pool_event.filter
      ; Experiment.Updated experiment |> Pool_event.experiment
      ]
  ;;

  let effects id =
    BaseGuard.ValidationSet.And
      [ Experiment.Guard.Access.update id; Filter.Guard.Access.create ]
  ;;
end

module UpdateFilter : sig
  include Common.CommandSig with type t = Filter.query

  val handle
    :  ?tags:Logs.Tag.set
    -> Filter.Key.human list
    -> Filter.t list
    -> Filter.t
    -> t
    -> (Pool_event.t list, Pool_common.Message.error) result

  val effects : Experiment.Id.t -> Filter.Id.t -> BaseGuard.ValidationSet.t
end = struct
  type t = Filter.query

  let handle ?(tags = Logs.Tag.empty) key_list template_list filter query =
    Logs.info ~src (fun m -> m "Handle command UpdateFilter" ~tags);
    let open CCResult in
    let* query = Filter.validate_query key_list template_list query in
    let filter = Filter.{ filter with query } in
    Ok [ Filter.Updated filter |> Pool_event.filter ]
  ;;

  let effects experiment_id filter_id =
    BaseGuard.ValidationSet.And
      [ Experiment.Guard.Access.update experiment_id
      ; Filter.Guard.Access.update filter_id
      ]
  ;;
end

module DeleteFilter : sig
  include Common.CommandSig with type t = Experiment.t

  val handle
    :  ?tags:Logs.Tag.set
    -> t
    -> (Pool_event.t list, Pool_common.Message.error) result

  val effects : Id.t -> Filter.Id.t -> BaseGuard.ValidationSet.t
end = struct
  type t = Experiment.t

  let handle ?(tags = Logs.Tag.empty) experiment =
    Logs.info ~src (fun m -> m "Handle command Delete" ~tags);
    let filter_event =
      experiment.Experiment.filter
      |> CCOption.map_or ~default:[] (fun f ->
        [ Filter.Deleted f |> Pool_event.filter ])
    in
    let experiment = Experiment.{ experiment with filter = None } in
    Ok
      ([ Experiment.Updated experiment |> Pool_event.experiment ] @ filter_event)
  ;;

  let effects experiment_id filter_id =
    BaseGuard.ValidationSet.And
      [ Experiment.Guard.Access.update experiment_id
      ; Filter.Guard.Access.delete filter_id
      ]
  ;;
end
