include Entity
module Guard = Entity_guard

let create database_label ?(period = default_period) () =
  let open Repo in
  let%lwt active_contacts = active_contacts database_label in
  let%lwt pending_contact_imports = pending_contact_imports database_label in
  let%lwt login_count = login_count database_label period in
  let%lwt sign_up_count = sign_up_count database_label period in
  let%lwt assignments_created = assignments_created database_label period in
  let%lwt invitations_sent = invitations_sent database_label period in
  let%lwt reminders_sent = reminders_sent database_label period in
  let%lwt terms_accepted_count = terms_accepted_count database_label period in
  let%lwt terms_last_changed =
    Settings.terms_and_conditions_last_updated database_label
  in
  Lwt.return
    { active_contacts
    ; pending_contact_imports
    ; login_count
    ; sign_up_count
    ; terms_accepted_count
    ; terms_last_changed
    ; assignments_created
    ; invitations_sent
    ; reminders_sent
    }
;;
