open CCFun
module Database = Pool_database
module Dynparam = Utils.Database.Dynparam

let src = Logs.Src.create "experiment.repo"

module Sql = struct
  let default_order_by = "pool_experiments.created_at"

  let insert_sql =
    {sql|
      INSERT INTO pool_experiments (
        uuid,
        title,
        public_title,
        description,
        cost_center,
        organisational_unit_uuid,
        filter_uuid,
        contact_person_uuid,
        smtp_auth_uuid,
        direct_registration_disabled,
        registration_disabled,
        allow_uninvited_signup,
        external_data_required,
        show_external_data_id_links,
        experiment_type,
        email_session_reminder_lead_time,
        text_message_session_reminder_lead_time,
        invitation_reset_at
      ) VALUES (
        UNHEX(REPLACE(?, '-', '')),
        ?,
        ?,
        ?,
        ?,
        UNHEX(REPLACE(?, '-', '')),
        UNHEX(REPLACE(?, '-', '')),
        UNHEX(REPLACE(?, '-', '')),
        UNHEX(REPLACE(?, '-', '')),
        ?,
        ?,
        ?,
        ?,
        ?,
        ?,
        ?,
        ?,
        ?
      )
    |sql}
  ;;

  let insert_request =
    let open Caqti_request.Infix in
    insert_sql |> Repo_entity.Write.t ->. Caqti_type.unit
  ;;

  let insert pool experiment =
    let open Entity in
    let autofill_public_title_request =
      {sql|
        UPDATE pool_experiments
        SET
          public_title = CONCAT('#', id)
        WHERE
          uuid = UNHEX(REPLACE($1, '-', ''))
        AND
          public_title = $2
      |sql}
    in
    let autofill_public_title =
      let open Caqti_request.Infix in
      autofill_public_title_request
      |> Caqti_type.(tup2 Repo_entity.Id.t Repo_entity.PublicTitle.t ->. unit)
    in
    let with_connection request input connection =
      let (module Connection : Caqti_lwt.CONNECTION) = connection in
      Connection.exec request input
    in
    let insert = with_connection insert_request experiment in
    let set_title =
      with_connection
        autofill_public_title
        (experiment.id, PublicTitle.placeholder)
    in
    Utils.Database.exec_as_transaction
      (Pool_database.Label.value pool)
      [ insert; set_title ]
  ;;

  let select_from_experiments_sql where_fragment =
    let select_from =
      {sql|
        SELECT
          LOWER(CONCAT(
            SUBSTR(HEX(pool_experiments.uuid), 1, 8), '-',
            SUBSTR(HEX(pool_experiments.uuid), 9, 4), '-',
            SUBSTR(HEX(pool_experiments.uuid), 13, 4), '-',
            SUBSTR(HEX(pool_experiments.uuid), 17, 4), '-',
            SUBSTR(HEX(pool_experiments.uuid), 21)
          )),
          pool_experiments.title,
          pool_experiments.public_title,
          pool_experiments.description,
          pool_experiments.cost_center,
          LOWER(CONCAT(
            SUBSTR(HEX(pool_organisational_units.uuid), 1, 8), '-',
            SUBSTR(HEX(pool_organisational_units.uuid), 9, 4), '-',
            SUBSTR(HEX(pool_organisational_units.uuid), 13, 4), '-',
            SUBSTR(HEX(pool_organisational_units.uuid), 17, 4), '-',
            SUBSTR(HEX(pool_organisational_units.uuid), 21)
          )),
          pool_organisational_units.name,
          LOWER(CONCAT(
            SUBSTR(HEX(pool_filter.uuid), 1, 8), '-',
            SUBSTR(HEX(pool_filter.uuid), 9, 4), '-',
            SUBSTR(HEX(pool_filter.uuid), 13, 4), '-',
            SUBSTR(HEX(pool_filter.uuid), 17, 4), '-',
            SUBSTR(HEX(pool_filter.uuid), 21)
          )),
          pool_filter.query,
          pool_filter.title,
          pool_filter.created_at,
          pool_filter.updated_at,
          LOWER(CONCAT(
            SUBSTR(HEX(pool_experiments.contact_person_uuid), 1, 8), '-',
            SUBSTR(HEX(pool_experiments.contact_person_uuid), 9, 4), '-',
            SUBSTR(HEX(pool_experiments.contact_person_uuid), 13, 4), '-',
            SUBSTR(HEX(pool_experiments.contact_person_uuid), 17, 4), '-',
            SUBSTR(HEX(pool_experiments.contact_person_uuid), 21)
          )),
          LOWER(CONCAT(
            SUBSTR(HEX(pool_experiments.smtp_auth_uuid), 1, 8), '-',
            SUBSTR(HEX(pool_experiments.smtp_auth_uuid), 9, 4), '-',
            SUBSTR(HEX(pool_experiments.smtp_auth_uuid), 13, 4), '-',
            SUBSTR(HEX(pool_experiments.smtp_auth_uuid), 17, 4), '-',
            SUBSTR(HEX(pool_experiments.smtp_auth_uuid), 21)
          )),
          pool_experiments.direct_registration_disabled,
          pool_experiments.registration_disabled,
          pool_experiments.allow_uninvited_signup,
          pool_experiments.external_data_required,
          pool_experiments.show_external_data_id_links,
          pool_experiments.experiment_type,
          pool_experiments.email_session_reminder_lead_time,
          pool_experiments.text_message_session_reminder_lead_time,
          pool_experiments.invitation_reset_at,
          pool_experiments.created_at,
          pool_experiments.updated_at
        FROM pool_experiments
        LEFT JOIN pool_filter
          ON pool_filter.uuid = pool_experiments.filter_uuid
        LEFT JOIN pool_organisational_units
          ON pool_organisational_units.uuid = pool_experiments.organisational_unit_uuid
      |sql}
    in
    Format.asprintf "%s %s" select_from where_fragment
  ;;

  let search_select =
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
        FROM pool_experiments
    |sql}
  ;;

  let validate_experiment_sql m = Format.asprintf " AND %s " m, Dynparam.empty

  let select_count where_fragment =
    Format.asprintf
      {sql|
        SELECT COUNT(*)
        FROM pool_experiments
        %s
      |sql}
      where_fragment
  ;;

  let find_all ?query ?actor ?permission pool =
    let open Utils.Lwt_result.Infix in
    let checks = [ Format.asprintf "pool_experiments.uuid IN %s" ] in
    let%lwt where =
      Guard.create_where ?actor ?permission ~checks pool `Experiment
      ||> CCOption.map (fun m -> m, Dynparam.empty)
    in
    Query.collect_and_count
      pool
      query
      ~select:select_from_experiments_sql
      ~count:select_count
      ?where
      Repo_entity.t
  ;;

  let find_request =
    let open Caqti_request.Infix in
    {sql|
      WHERE pool_experiments.uuid = UNHEX(REPLACE(?, '-', ''))
    |sql}
    |> select_from_experiments_sql
    |> Caqti_type.string ->! Repo_entity.t
  ;;

  let find pool id =
    let open Utils.Lwt_result.Infix in
    Utils.Database.find_opt
      (Pool_database.Label.value pool)
      find_request
      (id |> Entity.Id.value)
    ||> CCOption.to_result Pool_common.Message.(NotFound Field.Experiment)
  ;;

  let find_of_session =
    let open Caqti_request.Infix in
    {sql|
      INNER JOIN pool_sessions
        ON pool_experiments.uuid = pool_sessions.experiment_uuid
      WHERE pool_sessions.uuid = UNHEX(REPLACE(?, '-', ''))
    |sql}
    |> select_from_experiments_sql
    |> Caqti_type.string ->! Repo_entity.t
  ;;

  let find_of_session pool id =
    let open Utils.Lwt_result.Infix in
    Utils.Database.find_opt
      (Pool_database.Label.value pool)
      find_of_session
      (id |> Pool_common.Id.value)
    ||> CCOption.to_result Pool_common.Message.(NotFound Field.Experiment)
  ;;

  let find_of_mailing =
    let open Caqti_request.Infix in
    {sql|
      WHERE pool_experiments.uuid = (SELECT experiment_uuid FROM pool_mailing WHERE uuid = UNHEX(REPLACE(?, '-', '')) )
    |sql}
    |> select_from_experiments_sql
    |> Caqti_type.string ->! Repo_entity.t
  ;;

  let find_of_mailing pool id =
    let open Utils.Lwt_result.Infix in
    Utils.Database.find_opt
      (Pool_database.Label.value pool)
      find_of_mailing
      (id |> Pool_common.Id.value)
    ||> CCOption.to_result Pool_common.Message.(NotFound Field.Experiment)
  ;;

  let session_count_request =
    let open Caqti_request.Infix in
    {sql|
      SELECT COUNT(1) FROM pool_sessions WHERE experiment_uuid = UNHEX(REPLACE(?, '-', ''))
    |sql}
    |> Caqti_type.(string ->! int)
  ;;

  let session_count pool id =
    Utils.Database.find
      (Pool_database.Label.value pool)
      session_count_request
      (id |> Pool_common.Id.value)
  ;;

  let update_request =
    let open Caqti_request.Infix in
    {sql|
      UPDATE pool_experiments
      SET
        title = $2,
        public_title = $3,
        description = $4,
        cost_center = $5,
        organisational_unit_uuid = UNHEX(REPLACE($6, '-', '')),
        filter_uuid = UNHEX(REPLACE($7, '-', '')),
        contact_person_uuid = UNHEX(REPLACE($8, '-', '')),
        smtp_auth_uuid = UNHEX(REPLACE($9, '-', '')),
        direct_registration_disabled = $10,
        registration_disabled = $11,
        allow_uninvited_signup = $12,
        external_data_required = $13,
        show_external_data_id_links = $14,
        experiment_type = $15,
        email_session_reminder_lead_time = $16,
        text_message_session_reminder_lead_time = $17,
        invitation_reset_at = $18
      WHERE
        uuid = UNHEX(REPLACE($1, '-', ''))
    |sql}
    |> Repo_entity.Write.t ->. Caqti_type.unit
  ;;

  let update pool =
    Utils.Database.exec (Database.Label.value pool) update_request
  ;;

  let delete_request =
    let open Caqti_request.Infix in
    {sql|
      DELETE FROM pool_experiments
      WHERE uuid = UNHEX(REPLACE($1, '-', ''))
    |sql}
    |> Caqti_type.(string ->. unit)
  ;;

  let delete pool id =
    Utils.Database.exec
      (Pool_database.Label.value pool)
      delete_request
      (id |> Entity.Id.value)
  ;;

  let search_request ?conditions ?joins ~limit () =
    let default_contidion = "pool_experiments.title LIKE ?" in
    let joined_select =
      CCOption.map_or
        ~default:search_select
        (Format.asprintf "%s %s" search_select)
        joins
    in
    let where =
      CCOption.map_or
        ~default:default_contidion
        (Format.asprintf "%s AND %s" default_contidion)
        conditions
    in
    Format.asprintf "%s WHERE %s LIMIT %i" joined_select where limit
  ;;

  let search
    ?conditions
    ?(dyn = Dynparam.empty)
    ?exclude
    ?joins
    ?(limit = 20)
    pool
    query
    =
    let open Caqti_request.Infix in
    let exclude_ids =
      Utils.Database.exclude_ids "pool_experiments.uuid" Entity.Id.value
    in
    let dyn = Dynparam.(dyn |> add Caqti_type.string ("%" ^ query ^ "%")) in
    let dyn, exclude =
      exclude |> CCOption.map_or ~default:(dyn, None) (exclude_ids dyn)
    in
    let conditions =
      [ conditions; exclude ]
      |> CCList.filter_map CCFun.id
      |> function
      | [] -> None
      | conditions -> conditions |> CCString.concat " AND " |> CCOption.return
    in
    let (Dynparam.Pack (pt, pv)) = dyn in
    let request =
      search_request ?conditions ?joins ~limit ()
      |> pt ->* Repo_entity.(Caqti_type.tup2 Id.t Title.t)
    in
    Utils.Database.collect (pool |> Pool_database.Label.value) request pv
  ;;

  let search_multiple_by_id_request ids =
    Format.asprintf
      {sql|
        %s
        WHERE pool_experiments.uuid in ( %s )
      |sql}
      search_select
      (CCList.map (fun _ -> Format.asprintf "UNHEX(REPLACE(?, '-', ''))") ids
       |> CCString.concat ",")
  ;;

  let search_multiple_by_id pool ids =
    let open Caqti_request.Infix in
    match ids with
    | [] -> Lwt.return []
    | ids ->
      let dyn =
        CCList.fold_left
          (fun dyn id ->
            dyn |> Dynparam.add Caqti_type.string (id |> Pool_common.Id.value))
          Dynparam.empty
          ids
      in
      let (Dynparam.Pack (pt, pv)) = dyn in
      let request =
        search_multiple_by_id_request ids
        |> pt ->* Caqti_type.(Repo_entity.(tup2 Repo_entity.Id.t Title.t))
      in
      Utils.Database.collect (pool |> Database.Label.value) request pv
  ;;

  let find_all_ids_of_contact_id_request =
    let open Caqti_request.Infix in
    {sql|
        SELECT
          LOWER(CONCAT(
            SUBSTR(HEX(pool_experiments.uuid), 1, 8), '-',
            SUBSTR(HEX(pool_experiments.uuid), 9, 4), '-',
            SUBSTR(HEX(pool_experiments.uuid), 13, 4), '-',
            SUBSTR(HEX(pool_experiments.uuid), 17, 4), '-',
            SUBSTR(HEX(pool_experiments.uuid), 21)
          ))
        FROM pool_experiments
        INNER JOIN pool_sessions
          ON pool_experiments.uuid = pool_sessions.experiment_uuid
        INNER JOIN pool_assignments
          ON pool_sessions.uuid = pool_assignments.session_uuid
        WHERE pool_assignments.contact_uuid = UNHEX(REPLACE(?, '-', ''))
      |sql}
    |> Pool_common.Repo.Id.t ->* Repo_entity.Id.t
  ;;

  let find_all_ids_of_contact_id pool id =
    Utils.Database.collect
      (pool |> Database.Label.value)
      find_all_ids_of_contact_id_request
      (Contact.Id.to_common id)
  ;;

  let find_to_enroll_directly_request where =
    let open Caqti_request.Infix in
    Format.asprintf
      {sql|
        SELECT DISTINCT
          LOWER(CONCAT(
            SUBSTR(HEX(pool_experiments.uuid), 1, 8), '-',
            SUBSTR(HEX(pool_experiments.uuid), 9, 4), '-',
            SUBSTR(HEX(pool_experiments.uuid), 13, 4), '-',
            SUBSTR(HEX(pool_experiments.uuid), 17, 4), '-',
            SUBSTR(HEX(pool_experiments.uuid), 21)
          )),
          pool_experiments.title,
          pool_experiments.public_title,
          pool_filter.query,
          pool_experiments.direct_registration_disabled,
          pool_experiments.registration_disabled,
          COUNT(pool_sessions.uuid) > 0,
          EXISTS(
            SELECT TRUE FROM pool_sessions
            LEFT JOIN pool_assignments
              ON pool_assignments.session_uuid = pool_sessions.uuid
              AND pool_assignments.contact_uuid = UNHEX(REPLACE($2, '-', ''))
            WHERE pool_sessions.experiment_uuid = pool_experiments.uuid
              AND pool_assignments.canceled_at IS NULL
              AND pool_assignments.marked_as_deleted = 0
          )
        FROM
          pool_experiments
          LEFT JOIN pool_filter ON pool_filter.uuid = pool_experiments.filter_uuid
          LEFT JOIN pool_sessions ON pool_sessions.experiment_uuid = pool_experiments.uuid
            AND pool_sessions.closed_at IS NULL
            AND pool_sessions.canceled_at IS NULL
            AND pool_sessions.max_participants + pool_sessions.overbook >
            (SELECT COUNT(*) FROM pool_assignments
             WHERE pool_assignments.session_uuid = pool_sessions.uuid
               AND pool_assignments.canceled_at IS NULL
               AND pool_assignments.marked_as_deleted = 0)
          WHERE
            (pool_experiments.title LIKE $1
            OR pool_experiments.public_title LIKE $1)
            %s
          GROUP BY
            pool_experiments.uuid
          ORDER BY
            pool_experiments.created_at DESC
          LIMIT 5
        |sql}
      (where |> CCOption.map_or ~default:"" (fun where -> "AND " ^ where))
    |> Caqti_type.(tup2 string Pool_common.Repo.Id.t)
       ->* Repo_entity.DirectEnrollment.t
  ;;

  let find_to_enroll_directly ?actor pool contact ~query =
    let open Utils.Lwt_result.Infix in
    let open Entity in
    let checks = [ Format.asprintf "pool_experiments.uuid IN %s" ] in
    let%lwt where =
      let open Guard in
      let permission = CCOption.map (const Permission.Create) actor in
      create_where ?actor ?permission ~checks pool `Assignment
    in
    Utils.Database.collect
      (Pool_database.Label.value pool)
      (find_to_enroll_directly_request where)
      ("%" ^ query ^ "%", Contact.(contact |> id |> Id.to_common))
    >|> Lwt_list.map_s (fun ({ DirectEnrollment.filter; _ } as experiment) ->
      let%lwt matches_filter =
        match filter with
        | None -> Lwt.return_true
        | Some filter -> Filter.contact_matches_filter pool filter contact
      in
      Lwt.return DirectEnrollment.{ experiment with matches_filter })
  ;;

  let contact_is_enrolled_request =
    let open Caqti_request.Infix in
    {sql|
    SELECT
      EXISTS (
        SELECT
          1
        FROM
          pool_assignments
          INNER JOIN pool_sessions ON pool_assignments.session_uuid = pool_sessions.uuid
          INNER JOIN pool_experiments ON pool_experiments.uuid = pool_sessions.experiment_uuid
        WHERE
          pool_sessions.canceled_at IS NULL
          AND pool_assignments.marked_as_deleted = 0
          AND pool_experiments.uuid = UNHEX(REPLACE(?, '-', ''))
          AND pool_assignments.contact_uuid = UNHEX(REPLACE(?, '-', '')))
    |sql}
    |> Caqti_type.(tup2 string string ->! bool)
  ;;

  let contact_is_enrolled pool experiment_id contact_id =
    Utils.Database.find
      (Pool_database.Label.value pool)
      contact_is_enrolled_request
      (experiment_id |> Entity.Id.value, contact_id |> Contact.Id.value)
  ;;

  let find_targets_grantable_by_admin ?exclude database_label admin role query =
    let joins =
      {sql|
      LEFT JOIN guardian_actor_role_targets t ON t.target_uuid = pool_experiments.uuid
        AND t.actor_uuid = UNHEX(REPLACE(?, '-', ''))
        AND t.role = ?
    |sql}
    in
    let conditions = "t.role IS NULL" in
    let dyn =
      Dynparam.(
        empty
        |> add Caqti_type.string Admin.(id admin |> Id.value)
        |> add Caqti_type.string Role.Role.(show role))
    in
    search ~conditions ~joins ~dyn ?exclude database_label query
  ;;
end

let find = Sql.find
let find_all = Sql.find_all
let find_all_ids_of_contact_id = Sql.find_all_ids_of_contact_id
let find_of_session = Sql.find_of_session
let find_of_mailing = Sql.find_of_mailing
let session_count = Sql.session_count
let insert = Sql.insert
let update = Sql.update
let delete = Sql.delete
let search = Sql.search
let search_multiple_by_id = Sql.search_multiple_by_id
let find_to_enroll_directly = Sql.find_to_enroll_directly
let contact_is_enrolled = Sql.contact_is_enrolled
let find_targets_grantable_by_admin = Sql.find_targets_grantable_by_admin
