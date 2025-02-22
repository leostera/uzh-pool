open Entity

module RepoEntity = struct
  open CCFun.Infix

  let int_caqti of_int value =
    Pool_common.Repo.make_caqti_type
      Caqti_type.int
      (of_int %> CCResult.return)
      value
  ;;

  module ActiveContacts = struct
    include ActiveContacts

    let t = int_caqti of_int value
  end

  module PendingContactImports = struct
    include PendingContactImports

    let t = int_caqti of_int value
  end

  module SignUpCount = struct
    include SignUpCount

    let t = int_caqti of_int value
  end

  module LoginCount = struct
    include LoginCount

    let t = int_caqti of_int value
  end

  module TermsAcceptedCount = struct
    include TermsAcceptedCount

    let t = int_caqti of_int value
  end

  module AssignmentsCreated = struct
    include AssignmentsCreated

    let t = int_caqti of_int value
  end

  module InvitationsSent = struct
    include InvitationsSent

    let t = int_caqti of_int value
  end

  module RemindersSent = struct
    include RemindersSent

    let t = int_caqti of_int value
  end
end

let count_contacts_select =
  {sql|
    SELECT
      COUNT(*)
    FROM
      pool_contacts
      INNER JOIN user_users ON user_users.uuid = pool_contacts.user_uuid
    WHERE
      user_users.admin = 0
      AND user_users.confirmed = 1
      AND pool_contacts.email_verified IS NOT NULL
      AND pool_contacts.disabled = 0
      AND pool_contacts.paused = 0
      AND pool_contacts.import_pending = 0
  |sql}
;;

let active_contacts_request =
  let open Caqti_request.Infix in
  count_contacts_select |> Caqti_type.(unit ->! RepoEntity.ActiveContacts.t)
;;

let active_contacts pool =
  Utils.Database.find
    (Pool_database.Label.value pool)
    active_contacts_request
    ()
;;

let pending_contact_imports_request =
  let open Caqti_request.Infix in
  {sql|
    SELECT
      COUNT(*)
    FROM
      pool_contacts
      INNER JOIN user_users ON user_users.uuid = pool_contacts.user_uuid
    WHERE
      user_users.admin = 0
      AND pool_contacts.import_pending = 1
  |sql}
  |> Caqti_type.(unit ->! RepoEntity.PendingContactImports.t)
;;

let pending_contact_imports pool =
  Utils.Database.find
    (Pool_database.Label.value pool)
    pending_contact_imports_request
    ()
;;

let login_count_request period =
  let open Caqti_request.Infix in
  Format.asprintf
    {sql|
      SELECT
        COUNT(*)
      FROM
        pool_contacts
      WHERE
        last_sign_in_at >= (NOW() - INTERVAL %s)
    |sql}
    (Entity.period_to_sql period)
  |> Caqti_type.(unit ->! RepoEntity.LoginCount.t)
;;

let login_count pool period =
  Utils.Database.find
    (Pool_database.Label.value pool)
    (login_count_request period)
    ()
;;

let sign_up_count_request period =
  let open Caqti_request.Infix in
  Format.asprintf
    {sql|
      SELECT
        COUNT(*)
      FROM
        pool_contacts
      INNER JOIN user_users
        ON pool_contacts.user_uuid = user_users.uuid
      WHERE
        user_users.created_at >= (NOW() - INTERVAL %s)
      AND
        pool_contacts.email_verified IS NOT NULL
      AND
        pool_contacts.terms_accepted_at IS NOT NULL
    |sql}
    (Entity.period_to_sql period)
  |> Caqti_type.(unit ->! RepoEntity.SignUpCount.t)
;;

let sign_up_count pool period =
  Utils.Database.find
    (Pool_database.Label.value pool)
    (sign_up_count_request period)
    ()
;;

let assignments_created_request period =
  let open Caqti_request.Infix in
  Format.asprintf
    {sql|
      SELECT
        COUNT(*)
      FROM
        pool_assignments
      WHERE
        created_at >= (NOW() - INTERVAL %s)
        AND pool_assignments.canceled_at IS NULL
        AND pool_assignments.marked_as_deleted = 0
    |sql}
    (Entity.period_to_sql period)
  |> Caqti_type.(unit ->! RepoEntity.AssignmentsCreated.t)
;;

let assignments_created pool period =
  Utils.Database.find
    (Pool_database.Label.value pool)
    (assignments_created_request period)
    ()
;;

let invitations_sent_request period =
  let open Caqti_request.Infix in
  Format.asprintf
    {sql|
      SELECT COUNT(*) FROM pool_invitations WHERE created_at >= (NOW() - INTERVAL %s);
    |sql}
    (Entity.period_to_sql period)
  |> Caqti_type.(unit ->! RepoEntity.InvitationsSent.t)
;;

let invitations_sent pool period =
  Utils.Database.find
    (Pool_database.Label.value pool)
    (invitations_sent_request period)
    ()
;;

let reminders_sent_request period =
  let open Caqti_request.Infix in
  Format.asprintf
    {sql|
      SELECT
        COUNT(*)
      FROM
        pool_assignments
        INNER JOIN pool_sessions ON pool_assignments.session_uuid = pool_sessions.uuid
      WHERE
        pool_sessions.email_reminder_sent_at >= (NOW() - INTERVAL %s)
        AND pool_assignments.marked_as_deleted = 0
        AND pool_assignments.canceled_at IS NULL
    |sql}
    (Entity.period_to_sql period)
  |> Caqti_type.(unit ->! RepoEntity.RemindersSent.t)
;;

let reminders_sent pool period =
  Utils.Database.find
    (Pool_database.Label.value pool)
    (reminders_sent_request period)
    ()
;;

let terms_accepted_count_request period =
  let open Caqti_request.Infix in
  Format.asprintf
    {sql|
      %s
      AND pool_contacts.terms_accepted_at >= (NOW() - INTERVAL %s)
    |sql}
    count_contacts_select
    (Entity.period_to_sql period)
  |> Caqti_type.(unit ->! RepoEntity.TermsAcceptedCount.t)
;;

let terms_accepted_count pool period =
  Utils.Database.find
    (Pool_database.Label.value pool)
    (terms_accepted_count_request period)
    ()
;;
