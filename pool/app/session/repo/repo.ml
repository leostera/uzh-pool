module Database = Pool_database
module RepoEntity = Repo_entity
module Dynparam = Utils.Database.Dynparam

let of_entity = RepoEntity.of_entity
let to_entity = RepoEntity.to_entity

module Sql = struct
  let select_for_calendar ?order_by where =
    let order_by =
      order_by |> CCOption.map_or ~default:"" (Format.asprintf "ORDER BY %s")
    in
    Format.asprintf
      {sql|
      SELECT
        LOWER(CONCAT(
          SUBSTR(HEX(pool_sessions.uuid), 1, 8), '-',
          SUBSTR(HEX(pool_sessions.uuid), 9, 4), '-',
          SUBSTR(HEX(pool_sessions.uuid), 13, 4), '-',
          SUBSTR(HEX(pool_sessions.uuid), 17, 4), '-',
          SUBSTR(HEX(pool_sessions.uuid), 21)
        )),
        pool_experiments.title,
        LOWER(CONCAT(
          SUBSTR(HEX(pool_experiments.uuid), 1, 8), '-',
          SUBSTR(HEX(pool_experiments.uuid), 9, 4), '-',
          SUBSTR(HEX(pool_experiments.uuid), 13, 4), '-',
          SUBSTR(HEX(pool_experiments.uuid), 17, 4), '-',
          SUBSTR(HEX(pool_experiments.uuid), 21)
        )),
        pool_sessions.start,
        pool_sessions.duration,
        pool_sessions.description,
        pool_sessions.max_participants,
        pool_sessions.min_participants,
        pool_sessions.overbook,
        (SELECT
          COUNT(uuid)
        FROM
          pool_assignments
        WHERE
          pool_assignments.session_uuid = pool_sessions.uuid
          AND pool_assignments.canceled_at IS NULL
          AND pool_assignments.marked_as_deleted = 0),
        LOWER(CONCAT(
          SUBSTR(HEX(pool_locations.uuid), 1, 8), '-',
          SUBSTR(HEX(pool_locations.uuid), 9, 4), '-',
          SUBSTR(HEX(pool_locations.uuid), 13, 4), '-',
          SUBSTR(HEX(pool_locations.uuid), 17, 4), '-',
          SUBSTR(HEX(pool_locations.uuid), 21)
        )),
        pool_locations.name,
        user_users.given_name,
        user_users.name,
        user_users.email
      FROM pool_sessions
      INNER JOIN pool_experiments
        ON pool_sessions.experiment_uuid = pool_experiments.uuid
      INNER JOIN pool_locations
        ON pool_sessions.location_uuid = pool_locations.uuid
      LEFT JOIN user_users
        ON pool_experiments.contact_person_uuid = user_users.uuid
      WHERE
        %s
        %s
    |sql}
      where
      order_by
  ;;

  let find_sql ?order_by where =
    let order_by =
      order_by |> CCOption.map_or ~default:"" (Format.asprintf "ORDER BY %s")
    in
    let select =
      {sql|
        SELECT
          LOWER(CONCAT(
            SUBSTR(HEX(pool_sessions.uuid), 1, 8), '-',
            SUBSTR(HEX(pool_sessions.uuid), 9, 4), '-',
            SUBSTR(HEX(pool_sessions.uuid), 13, 4), '-',
            SUBSTR(HEX(pool_sessions.uuid), 17, 4), '-',
            SUBSTR(HEX(pool_sessions.uuid), 21)
          )),
          LOWER(CONCAT(
            SUBSTR(HEX(pool_sessions.follow_up_to), 1, 8), '-',
            SUBSTR(HEX(pool_sessions.follow_up_to), 9, 4), '-',
            SUBSTR(HEX(pool_sessions.follow_up_to), 13, 4), '-',
            SUBSTR(HEX(pool_sessions.follow_up_to), 17, 4), '-',
            SUBSTR(HEX(pool_sessions.follow_up_to), 21)
          )),
          (SELECT EXISTS (SELECT 1 FROM pool_sessions as s WHERE s.follow_up_to = pool_sessions.uuid LIMIT 1)),
          pool_sessions.start,
          pool_sessions.duration,
          pool_sessions.description,
          pool_sessions.limitations,
          LOWER(CONCAT(
            SUBSTR(HEX(pool_locations.uuid), 1, 8), '-',
            SUBSTR(HEX(pool_locations.uuid), 9, 4), '-',
            SUBSTR(HEX(pool_locations.uuid), 13, 4), '-',
            SUBSTR(HEX(pool_locations.uuid), 17, 4), '-',
            SUBSTR(HEX(pool_locations.uuid), 21)
          )),
          pool_sessions.max_participants,
          pool_sessions.min_participants,
          pool_sessions.overbook,
          pool_sessions.email_reminder_lead_time,
          pool_sessions.email_reminder_sent_at,
          pool_sessions.text_message_reminder_lead_time,
          pool_sessions.text_message_reminder_sent_at,
          COUNT(pool_assignments.id),
          COALESCE( SUM(pool_assignments.no_show), 0),
          COALESCE( SUM(pool_assignments.participated), 0),
          pool_sessions.closed_at,
          pool_sessions.canceled_at,
          pool_sessions.created_at,
          pool_sessions.updated_at
        FROM pool_sessions
        LEFT JOIN pool_assignments
          ON pool_assignments.session_uuid = pool_sessions.uuid
          AND pool_assignments.canceled_at IS NULL
          AND pool_assignments.marked_as_deleted = 0
        INNER JOIN pool_locations
          ON pool_locations.uuid = pool_sessions.location_uuid
      |sql}
    in
    Format.asprintf "%s %s GROUP BY pool_sessions.uuid %s" select where order_by
  ;;

  let find_public_sql where =
    let select =
      {sql|
        SELECT
          LOWER(CONCAT(
            SUBSTR(HEX(pool_sessions.uuid), 1, 8), '-',
            SUBSTR(HEX(pool_sessions.uuid), 9, 4), '-',
            SUBSTR(HEX(pool_sessions.uuid), 13, 4), '-',
            SUBSTR(HEX(pool_sessions.uuid), 17, 4), '-',
            SUBSTR(HEX(pool_sessions.uuid), 21)
          )),
          LOWER(CONCAT(
            SUBSTR(HEX(pool_sessions.follow_up_to), 1, 8), '-',
            SUBSTR(HEX(pool_sessions.follow_up_to), 9, 4), '-',
            SUBSTR(HEX(pool_sessions.follow_up_to), 13, 4), '-',
            SUBSTR(HEX(pool_sessions.follow_up_to), 17, 4), '-',
            SUBSTR(HEX(pool_sessions.follow_up_to), 21)
          )),
          pool_sessions.start,
          pool_sessions.duration,
          pool_sessions.description,
          LOWER(CONCAT(
            SUBSTR(HEX(pool_locations.uuid), 1, 8), '-',
            SUBSTR(HEX(pool_locations.uuid), 9, 4), '-',
            SUBSTR(HEX(pool_locations.uuid), 13, 4), '-',
            SUBSTR(HEX(pool_locations.uuid), 17, 4), '-',
            SUBSTR(HEX(pool_locations.uuid), 21)
          )),
          pool_sessions.max_participants,
          pool_sessions.min_participants,
          pool_sessions.overbook,
          (SELECT COUNT(pool_assignments.id) FROM pool_assignments WHERE session_uuid = pool_sessions.uuid AND marked_as_deleted = 0 AND pool_assignments.canceled_at IS NULL),
          pool_sessions.canceled_at
        FROM pool_sessions
        INNER JOIN pool_locations
          ON pool_locations.uuid = pool_sessions.location_uuid
      |sql}
    in
    Format.asprintf "%s %s" select where
  ;;

  let find_request =
    let open Caqti_request.Infix in
    {sql|
      WHERE pool_sessions.uuid = UNHEX(REPLACE(?, '-', ''))
    |sql}
    |> find_sql
    |> Caqti_type.string ->! RepoEntity.t
  ;;

  let find pool id =
    let open Utils.Lwt_result.Infix in
    Utils.Database.find_opt
      (Database.Label.value pool)
      find_request
      (Pool_common.Id.value id)
    ||> CCOption.to_result Pool_common.Message.(NotFound Field.Session)
  ;;

  let find_multiple_request ids =
    Format.asprintf
      {sql|
        WHERE pool_sessions.uuid IN ( %s )
      |sql}
      (CCList.mapi
         (fun i _ -> Format.asprintf "UNHEX(REPLACE($%n, '-', ''))" (i + 1))
         ids
       |> CCString.concat ",")
    |> find_sql
  ;;

  let find_multiple pool ids =
    let open Caqti_request.Infix in
    if CCList.is_empty ids
    then Lwt.return []
    else (
      let (Dynparam.Pack (pt, pv)) =
        CCList.fold_left
          (fun dyn id ->
            dyn |> Dynparam.add Caqti_type.string (id |> Entity.Id.value))
          Dynparam.empty
          ids
      in
      let request = find_multiple_request ids |> pt ->* RepoEntity.t in
      Utils.Database.collect (pool |> Pool_database.Label.value) request pv)
  ;;

  let find_contact_is_assigned_by_experiment_request =
    let open Caqti_request.Infix in
    {sql|
        SELECT
          LOWER(CONCAT(
            SUBSTR(HEX(pool_sessions.uuid), 1, 8), '-',
            SUBSTR(HEX(pool_sessions.uuid), 9, 4), '-',
            SUBSTR(HEX(pool_sessions.uuid), 13, 4), '-',
            SUBSTR(HEX(pool_sessions.uuid), 17, 4), '-',
            SUBSTR(HEX(pool_sessions.uuid), 21)
          ))
          FROM pool_sessions
          LEFT JOIN pool_assignments ON pool_assignments.session_uuid = pool_sessions.uuid
            AND pool_assignments.canceled_at IS NULL
            AND pool_assignments.marked_as_deleted = 0
          WHERE
            pool_assignments.contact_uuid = UNHEX(REPLACE(?, '-', ''))
            AND pool_sessions.experiment_uuid = UNHEX(REPLACE(?, '-', ''))
      |sql}
    |> Caqti_type.(tup2 string string) ->* RepoEntity.Id.t
  ;;

  let find_contact_is_assigned_by_experiment pool contact_id experiment_id =
    let open Utils.Lwt_result.Infix in
    Utils.Database.collect
      (Database.Label.value pool)
      find_contact_is_assigned_by_experiment_request
      (Contact.Id.value contact_id, Experiment.Id.value experiment_id)
    >|> find_multiple pool
  ;;

  let find_all_for_experiment_request =
    let open Caqti_request.Infix in
    {sql|
      WHERE pool_sessions.experiment_uuid = UNHEX(REPLACE(?, '-', ''))
    |sql}
    |> find_sql ~order_by:"pool_sessions.start"
    |> Caqti_type.string ->* RepoEntity.t
  ;;

  let find_all_for_experiment pool id =
    Utils.Database.collect
      (Database.Label.value pool)
      find_all_for_experiment_request
      (Experiment.Id.value id)
  ;;

  let find_all_to_assign_from_waitinglist_request =
    let open Caqti_request.Infix in
    {sql|
        WHERE pool_sessions.experiment_uuid = UNHEX(REPLACE(?, '-', ''))
        AND pool_sessions.start > NOW()
        AND pool_sessions.canceled_at IS NULL
      |sql}
    |> find_sql ~order_by:"pool_sessions.start"
    |> Caqti_type.string ->* RepoEntity.t
  ;;

  let find_all_to_assign_from_waitinglist pool id =
    Utils.Database.collect
      (Database.Label.value pool)
      find_all_to_assign_from_waitinglist_request
      (Experiment.Id.value id)
  ;;

  let find_all_ids_of_contact_id_request =
    let open Caqti_request.Infix in
    {sql|
      SELECT
        LOWER(CONCAT(
          SUBSTR(HEX(pool_sessions.uuid), 1, 8), '-',
          SUBSTR(HEX(pool_sessions.uuid), 9, 4), '-',
          SUBSTR(HEX(pool_sessions.uuid), 13, 4), '-',
          SUBSTR(HEX(pool_sessions.uuid), 17, 4), '-',
          SUBSTR(HEX(pool_sessions.uuid), 21)
        ))
      FROM pool_sessions
      INNER JOIN pool_assignments
        ON pool_assignments.session_uuid = pool_sessions.uuid
      WHERE pool_assignments.contact_uuid = UNHEX(REPLACE(?, '-', ''))
        AND pool_assignments.marked_as_deleted = 0
      |sql}
    |> Pool_common.Repo.Id.t ->* RepoEntity.Id.t
  ;;

  let find_all_ids_of_contact_id pool id =
    Utils.Database.collect
      (Database.Label.value pool)
      find_all_ids_of_contact_id_request
      (Contact.Id.to_common id)
  ;;

  let find_public_request =
    let open Caqti_request.Infix in
    {sql|
        WHERE pool_sessions.uuid = UNHEX(REPLACE(?, '-', ''))
        AND start > NOW()
        AND canceled_at IS NULL
        ORDER BY start
      |sql}
    |> find_public_sql
    |> Caqti_type.string ->! RepoEntity.Public.t
  ;;

  let find_public pool id =
    let open Utils.Lwt_result.Infix in
    Utils.Database.find_opt
      (Database.Label.value pool)
      find_public_request
      (Pool_common.Id.value id)
    ||> CCOption.to_result Pool_common.Message.(NotFound Field.Session)
  ;;

  let find_public_by_assignment_request =
    let open Caqti_request.Infix in
    {sql|
      INNER JOIN pool_assignments
        ON pool_assignments.session_uuid = pool_sessions.uuid
      WHERE pool_assignments.uuid = UNHEX(REPLACE(?, '-', ''))
        AND pool_assignments.marked_as_deleted = 0
    |sql}
    |> find_public_sql
    |> Caqti_type.string ->! RepoEntity.Public.t
  ;;

  let find_public_by_assignment pool id =
    let open Utils.Lwt_result.Infix in
    Utils.Database.find_opt
      (Database.Label.value pool)
      find_public_by_assignment_request
      (Pool_common.Id.value id)
    ||> CCOption.to_result Pool_common.Message.(NotFound Field.Session)
  ;;

  let find_public_upcoming_by_contact_request =
    let open Caqti_request.Infix in
    {sql|
      INNER JOIN pool_assignments
        ON pool_assignments.session_uuid = pool_sessions.uuid
        AND pool_assignments.canceled_at IS NULL
        AND pool_assignments.marked_as_deleted = 0
      WHERE
        pool_sessions.closed_at IS NULL
      AND
        pool_sessions.start > NOW()
      AND
        pool_assignments.contact_uuid = UNHEX(REPLACE(?, '-', ''))
      ORDER BY
        pool_sessions.start ASC
    |sql}
    |> find_public_sql
    |> Caqti_type.string ->* RepoEntity.Public.t
  ;;

  let find_public_upcoming_by_contact pool contact_id =
    Utils.Database.collect
      (Database.Label.value pool)
      find_public_upcoming_by_contact_request
      (Pool_common.Id.value contact_id)
  ;;

  let find_by_assignment_request =
    let open Caqti_request.Infix in
    {sql|
      WHERE pool_assignments.uuid = UNHEX(REPLACE(?, '-', ''))
    |sql}
    |> find_sql
    |> Caqti_type.string ->! RepoEntity.t
  ;;

  let find_by_assignment pool id =
    let open Utils.Lwt_result.Infix in
    Utils.Database.find_opt
      (Database.Label.value pool)
      find_by_assignment_request
      (Pool_common.Id.value id)
    ||> CCOption.to_result Pool_common.Message.(NotFound Field.Session)
  ;;

  let find_all_public_for_experiment_request =
    let open Caqti_request.Infix in
    {sql|
      WHERE experiment_uuid = UNHEX(REPLACE(?, '-', ''))
      AND start > NOW()
      AND canceled_at IS NULL
      ORDER BY start
    |sql}
    |> find_public_sql
    |> Caqti_type.string ->* RepoEntity.Public.t
  ;;

  let find_all_public_for_experiment pool id =
    Utils.Database.collect
      (Database.Label.value pool)
      find_all_public_for_experiment_request
      (Experiment.Id.value id)
  ;;

  let find_all_public_by_location_request =
    let open Caqti_request.Infix in
    {sql|
      WHERE pool_locations.uuid = UNHEX(REPLACE(?, '-', ''))
      ORDER BY start
    |sql}
    |> find_public_sql
    |> Caqti_type.string ->* RepoEntity.Public.t
  ;;

  let find_all_public_by_location pool id =
    Utils.Database.collect
      (Database.Label.value pool)
      find_all_public_by_location_request
      (Pool_location.Id.value id)
  ;;

  let find_experiment_id_and_title_request =
    let open Caqti_request.Infix in
    {sql|
      SELECT
        LOWER(CONCAT(
          SUBSTR(HEX(pool_experiments.uuid), 1, 8), '-',
          SUBSTR(HEX(pool_experiments.uuid), 9, 4), '-',
          SUBSTR(HEX(pool_experiments.uuid), 13, 4), '-',
          SUBSTR(HEX(pool_experiments.uuid), 17, 4), '-',
          SUBSTR(HEX(pool_experiments.uuid), 21)
        )),
        pool_experiments.title
      FROM pool_sessions
      INNER JOIN pool_experiments
        ON pool_experiments.uuid = pool_sessions.experiment_uuid
      WHERE pool_sessions.uuid = UNHEX(REPLACE(?, '-', ''))
    |sql}
    |> Caqti_type.(string ->! tup2 Experiment.Repo.Entity.Id.t string)
  ;;

  let find_experiment_id_and_title pool id =
    let open Utils.Lwt_result.Infix in
    Utils.Database.find_opt
      (Database.Label.value pool)
      find_experiment_id_and_title_request
      (Pool_common.Id.value id)
    ||> CCOption.to_result Pool_common.Message.(NotFound Field.Session)
  ;;

  let find_public_experiment_request =
    let open Caqti_request.Infix in
    {sql|
      WHERE pool_experiments.uuid = (SELECT pool_sessions.experiment_uuid FROM pool_sessions WHERE pool_sessions.uuid = UNHEX(REPLACE(?, '-', '')))
    |sql}
    |> Experiment.Repo.Public.select_from_experiments_sql
    |> Caqti_type.(string ->! Experiment.Repo.Public.Entity.t)
  ;;

  let find_public_experiment pool id =
    let open Utils.Lwt_result.Infix in
    Utils.Database.find_opt
      (Database.Label.value pool)
      find_public_experiment_request
      (Pool_common.Id.value id)
    ||> CCOption.to_result Pool_common.Message.(NotFound Field.Experiment)
  ;;

  let find_sessions_to_remind_request channel =
    let reminder_sent_at, lead_time =
      match channel with
      | `Email ->
        ( "pool_sessions.email_reminder_sent_at IS NULL"
        , {sql| pool_sessions.email_reminder_lead_time,
      pool_experiments.email_session_reminder_lead_time,
      (SELECT value FROM pool_system_settings WHERE settings_key = $1)|sql}
        )
      | `TextMessage ->
        ( "pool_sessions.text_message_reminder_sent_at IS NULL"
        , {sql| pool_sessions.text_message_reminder_lead_time,
      pool_experiments.text_message_session_reminder_lead_time,
      (SELECT value FROM pool_system_settings WHERE settings_key = $1)|sql}
        )
    in
    let open Caqti_request.Infix in
    Format.asprintf
      {sql|
    INNER JOIN pool_experiments
      ON pool_experiments.uuid = pool_sessions.experiment_uuid
    WHERE
      %s
    AND
      pool_sessions.canceled_at IS NULL
    AND
      pool_sessions.closed_at IS NULL
    AND
      pool_sessions.start >= NOW()
    AND
      pool_sessions.start <= DATE_ADD(NOW(), INTERVAL
        COALESCE(
          %s
        ) SECOND)
    |sql}
      reminder_sent_at
      lead_time
    |> find_sql
    |> Caqti_type.(string) ->* RepoEntity.t
  ;;

  let find_sessions_to_remind pool =
    let email_default_lead_time =
      Settings.default_email_session_reminder_lead_time_key_yojson
    in
    let text_message_default_lead_time =
      Settings.default_text_message_session_reminder_lead_time_key_yojson
    in
    let collect = Utils.Database.collect (Database.Label.value pool) in
    let%lwt email_reminders =
      collect
        (find_sessions_to_remind_request `Email)
        (email_default_lead_time |> Yojson.Safe.to_string)
    in
    let%lwt text_msg_reminders =
      collect
        (find_sessions_to_remind_request `TextMessage)
        (text_message_default_lead_time |> Yojson.Safe.to_string)
    in
    Lwt_result.return (email_reminders, text_msg_reminders)
  ;;

  let find_follow_ups_request =
    let open Caqti_request.Infix in
    {sql|
        WHERE pool_sessions.follow_up_to = UNHEX(REPLACE(?, '-', ''))
        AND pool_sessions.canceled_at IS NULL
      |sql}
    |> find_sql ~order_by:"pool_sessions.start"
    |> Caqti_type.string ->* RepoEntity.t
  ;;

  let find_follow_ups pool id =
    Utils.Database.collect
      (Database.Label.value pool)
      find_follow_ups_request
      (Pool_common.Id.value id)
  ;;

  let find_open_request =
    let open Caqti_request.Infix in
    {sql|
        WHERE
          pool_sessions.closed_at IS NULL
        AND
          pool_sessions.canceled_at IS NULL
        AND
          pool_sessions.uuid = UNHEX(REPLACE($1, '-', ''))
      |sql}
    |> find_sql
    |> Caqti_type.string ->! RepoEntity.t
  ;;

  let find_open pool id =
    Utils.Database.find_opt
      (Database.Label.value pool)
      find_open_request
      (Pool_common.Id.value id)
  ;;

  let find_open_with_follow_ups_request =
    let open Caqti_request.Infix in
    {sql|
        WHERE
          pool_sessions.closed_at IS NULL
        AND
          pool_sessions.canceled_at IS NULL
        AND (
          pool_sessions.uuid = UNHEX(REPLACE($1, '-', ''))
          OR
          pool_sessions.follow_up_to = UNHEX(REPLACE($1, '-', ''))
        )
      |sql}
    |> find_sql ~order_by:"pool_sessions.start"
    |> Caqti_type.string ->* RepoEntity.t
  ;;

  let find_open_with_follow_ups pool id =
    Utils.Database.collect
      (Database.Label.value pool)
      find_open_with_follow_ups_request
      (Pool_common.Id.value id)
  ;;

  let find_binary_experiment_id_sql =
    {sql|
      SELECT sessions.experiment_uuid
      FROM pool_sessions AS sessions
      WHERE sessions.uuid = ?
    |sql}
  ;;

  let insert_request =
    let open Caqti_request.Infix in
    {sql|
      INSERT INTO pool_sessions (
        uuid,
        follow_up_to,
        experiment_uuid,
        start,
        duration,
        description,
        limitations,
        location_uuid,
        max_participants,
        min_participants,
        overbook,
        email_reminder_lead_time,
        email_reminder_sent_at,
        text_message_reminder_lead_time,
        text_message_reminder_sent_at,
        closed_at,
        canceled_at
      ) VALUES (
        UNHEX(REPLACE($2, '-', '')),
        UNHEX(REPLACE($3, '-', '')),
        UNHEX(REPLACE($1, '-', '')),
        $4,
        $5,
        $6,
        $7,
        UNHEX(REPLACE($8, '-', '')),
        $9,
        $10,
        $11,
        $12,
        $13,
        $14,
        $15,
        $16,
        $17
      )
    |sql}
    |> Caqti_type.(tup2 string RepoEntity.Write.t ->. unit)
  ;;

  let insert pool (experiment_id, session) =
    Utils.Database.exec
      (Database.Label.value pool)
      insert_request
      (experiment_id, session |> RepoEntity.Write.entity_to_write)
  ;;

  let update_request =
    let open Caqti_request.Infix in
    {sql|
      UPDATE pool_sessions
      SET
        follow_up_to = UNHEX(REPLACE($2, '-', '')),
        start = $3,
        duration = $4,
        description = $5,
        limitations = $6,
        location_uuid = UNHEX(REPLACE($7, '-', '')),
        max_participants = $8,
        min_participants = $9,
        overbook = $10,
        email_reminder_lead_time = $11,
        email_reminder_sent_at = $12,
        text_message_reminder_lead_time = $13,
        text_message_reminder_sent_at = $14,
        closed_at = $15,
        canceled_at = $16
      WHERE
        uuid = UNHEX(REPLACE($1, '-', ''))
    |sql}
    |> RepoEntity.Write.t ->. Caqti_type.unit
  ;;

  let update pool m =
    Utils.Database.exec
      (Database.Label.value pool)
      update_request
      (m |> RepoEntity.Write.entity_to_write)
  ;;

  let delete_request =
    let open Caqti_request.Infix in
    {sql|
      DELETE FROM pool_sessions
      WHERE uuid = UNHEX(REPLACE(?, '-', ''))
    |sql}
    |> Caqti_type.(string ->. unit)
  ;;

  let delete pool id =
    Utils.Database.exec
      (Pool_database.Label.value pool)
      delete_request
      (Pool_common.Id.value id)
  ;;

  let find_for_calendar_by_location_request =
    let open Caqti_request.Infix in
    {sql|
        pool_sessions.canceled_at IS NULL
        AND pool_sessions.start > $2
        AND pool_sessions.start < $3
        AND pool_sessions.location_uuid = UNHEX(REPLACE($1, '-', ''))
      |sql}
    |> select_for_calendar ~order_by:"pool_sessions.start"
    |> Caqti_type.(tup3 string ptime ptime ->* RepoEntity.Calendar.t)
  ;;

  let find_for_calendar_by_location location_id pool ~start_time ~end_time =
    Utils.Database.collect
      (Database.Label.value pool)
      find_for_calendar_by_location_request
      (Pool_location.Id.value location_id, start_time, end_time)
  ;;

  let find_for_calendar_by_user_request =
    select_for_calendar ~order_by:"pool_sessions.start"
  ;;

  let find_for_calendar_by_user actor pool ~start_time ~end_time =
    let open Caqti_request.Infix in
    let%lwt guardian =
      Guard.sql_where_fragment
        ~field:"pool_experiments.uuid"
        pool
        Guard.Permission.Read
        `Experiment
        actor
    in
    let sql =
      [ "pool_sessions.start > ?"
      ; "pool_sessions.start < ?"
      ; "pool_sessions.canceled_at IS NULL"
      ]
      @ CCOption.to_list guardian
      |> CCString.concat " AND "
    in
    let dyn =
      let open Dynparam in
      CCList.fold_left
        (fun dyn p -> dyn |> add Caqti_type.ptime p)
        empty
        [ start_time; end_time ]
    in
    let (Dynparam.Pack (pt, pv)) = dyn in
    let request =
      find_for_calendar_by_user_request sql
      |> (pt ->* RepoEntity.Calendar.t) ~oneshot:true
    in
    Utils.Database.collect (pool |> Pool_database.Label.value) request pv
  ;;
end

let location_to_repo_entity pool session =
  let open Utils.Lwt_result.Infix in
  Pool_location.find pool session.RepoEntity.location_id >|+ to_entity session
;;

let add_location_to_multiple pool sessions =
  let open Utils.Lwt_result.Infix in
  sessions
  |> Lwt_list.map_s (location_to_repo_entity pool)
  ||> CCResult.flatten_l
;;

let location_to_public_repo_entity pool session =
  let open Utils.Lwt_result.Infix in
  Pool_location.find pool session.RepoEntity.Public.location_id
  >|+ RepoEntity.Public.to_entity session
;;

let find pool id =
  let open Utils.Lwt_result.Infix in
  Sql.find pool id >>= location_to_repo_entity pool
;;

let find_multiple pool ids =
  let open Utils.Lwt_result.Infix in
  Sql.find_multiple pool ids >|> add_location_to_multiple pool
;;

let find_contact_is_assigned_by_experiment pool contact_id experiment_id =
  let open Utils.Lwt_result.Infix in
  Sql.find_contact_is_assigned_by_experiment pool contact_id experiment_id
  >|> add_location_to_multiple pool
;;

(* TODO [aerben] these queries are very inefficient, how to circumvent? *)
let find_all_public_by_location pool location_id =
  let open Utils.Lwt_result.Infix in
  Sql.find_all_public_by_location pool location_id
  >|> Lwt_list.map_s (location_to_public_repo_entity pool)
  ||> CCResult.flatten_l
;;

let find_public pool id =
  let open Utils.Lwt_result.Infix in
  id |> Sql.find_public pool >>= location_to_public_repo_entity pool
;;

let find_all_for_experiment pool experiment_id =
  let open Utils.Lwt_result.Infix in
  Sql.find_all_for_experiment pool experiment_id
  >|> add_location_to_multiple pool
;;

let find_all_to_assign_from_waitinglist pool experiment_id =
  let open Utils.Lwt_result.Infix in
  Sql.find_all_to_assign_from_waitinglist pool experiment_id
  >|> add_location_to_multiple pool
;;

let find_all_public_for_experiment pool contact experiment_id =
  let open Utils.Lwt_result.Infix in
  Experiment.find_public pool experiment_id contact
  >>= fun experiment ->
  experiment.Experiment.Public.id
  |> Sql.find_all_public_for_experiment pool
  >|> Lwt_list.map_s (location_to_public_repo_entity pool)
  ||> CCResult.flatten_l
;;

let find_public_by_assignment pool assignment_id =
  let open Utils.Lwt_result.Infix in
  Sql.find_public_by_assignment pool assignment_id
  >>= location_to_public_repo_entity pool
;;

let find_by_assignment pool assignment_id =
  let open Utils.Lwt_result.Infix in
  Sql.find_by_assignment pool assignment_id >>= location_to_repo_entity pool
;;

let find_follow_ups pool parent_session_id =
  let open Utils.Lwt_result.Infix in
  Sql.find_follow_ups pool parent_session_id >|> add_location_to_multiple pool
;;

let find_open_with_follow_ups pool session_id =
  let open Utils.Lwt_result.Infix in
  Sql.find_open_with_follow_ups pool session_id
  ||> (function
         | [] -> Error Pool_common.Message.(NotFound Field.Session)
         | sessions -> Ok sessions)
  >>= add_location_to_multiple pool
;;

let find_open pool session_id =
  let open Utils.Lwt_result.Infix in
  Sql.find_open pool session_id
  ||> CCOption.to_result Pool_common.Message.(NotFound Field.Session)
  >>= location_to_repo_entity pool
;;

let find_experiment_id_and_title = Sql.find_experiment_id_and_title

let find_upcoming_public_by_contact pool contact_id =
  let open Utils.Lwt_result.Infix in
  let open Entity.Public in
  Sql.find_public_upcoming_by_contact pool contact_id
  >|> Lwt_list.map_s (location_to_public_repo_entity pool)
  ||> CCResult.flatten_l
  >|+ group_and_sort_keep_followups
  >>= fun lst ->
  lst
  |> Lwt_list.map_s (fun (parent, follow_ups) ->
    Sql.find_public_experiment pool parent.id
    >|+ fun exp -> exp, parent, follow_ups)
  ||> CCResult.flatten_l
;;

let find_sessions_to_remind pool =
  let open Utils.Lwt_result.Infix in
  Sql.find_sessions_to_remind pool
  >>= fun (email_reminders, text_message_reminders) ->
  let* email_reminders = add_location_to_multiple pool email_reminders in
  let* text_message_reminders =
    add_location_to_multiple pool text_message_reminders
  in
  Lwt_result.return (email_reminders, text_message_reminders)
;;

let insert = Sql.insert
let update = Sql.update
let delete = Sql.delete
let find_for_calendar_by_location = Sql.find_for_calendar_by_location
let find_for_calendar_by_user = Sql.find_for_calendar_by_user
let find_all_ids_of_contact_id = Sql.find_all_ids_of_contact_id
