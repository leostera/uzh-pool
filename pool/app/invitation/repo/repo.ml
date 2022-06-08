module RepoEntity = Repo_entity

let to_entity = RepoEntity.to_entity
let of_entity = RepoEntity.of_entity

module Sql = struct
  let select_sql =
    {sql|
      SELECT
        LOWER(CONCAT(
          SUBSTR(HEX(pool_invitations.uuid), 1, 8), '-',
          SUBSTR(HEX(pool_invitations.uuid), 9, 4), '-',
          SUBSTR(HEX(pool_invitations.uuid), 13, 4), '-',
          SUBSTR(HEX(pool_invitations.uuid), 17, 4), '-',
          SUBSTR(HEX(pool_invitations.uuid), 21)
        )),
        LOWER(CONCAT(
          SUBSTR(HEX(pool_experiments.uuid), 1, 8), '-',
          SUBSTR(HEX(pool_experiments.uuid), 9, 4), '-',
          SUBSTR(HEX(pool_experiments.uuid), 13, 4), '-',
          SUBSTR(HEX(pool_experiments.uuid), 17, 4), '-',
          SUBSTR(HEX(pool_experiments.uuid), 21)
        )),
        LOWER(CONCAT(
          SUBSTR(HEX(pool_contacts.user_uuid), 1, 8), '-',
          SUBSTR(HEX(pool_contacts.user_uuid), 9, 4), '-',
          SUBSTR(HEX(pool_contacts.user_uuid), 13, 4), '-',
          SUBSTR(HEX(pool_contacts.user_uuid), 17, 4), '-',
          SUBSTR(HEX(pool_contacts.user_uuid), 21)
        )),
        pool_invitations.resent_at,
        pool_invitations.created_at,
        pool_invitations.updated_at
      FROM
        pool_invitations
      LEFT JOIN pool_contacts
        ON pool_invitations.contact_id = pool_contacts.id
      LEFT JOIN pool_experiments
        ON pool_invitations.experiment_id = pool_experiments.id
    |sql}
  ;;

  let find_request =
    let open Caqti_request.Infix in
    {sql|
      WHERE
        pool_invitations.uuid = UNHEX(REPLACE(?, '-', ''))
    |sql}
    |> Format.asprintf "%s\n%s" select_sql
    |> Caqti_type.string ->! RepoEntity.t
  ;;

  let find pool id =
    let open Lwt.Infix in
    Utils.Database.find_opt
      (Pool_database.Label.value pool)
      find_request
      (Pool_common.Id.value id)
    >|= CCOption.to_result Pool_common.Message.(NotFound Field.Tenant)
  ;;

  let find_by_experiment_request =
    let open Caqti_request.Infix in
    {sql|
      WHERE
        experiment_id = (SELECT id FROM pool_experiments WHERE uuid = UNHEX(REPLACE(?, '-', '')))
    |sql}
    |> Format.asprintf "%s\n%s" select_sql
    |> Caqti_type.string ->* RepoEntity.t
  ;;

  let find_by_experiment pool id =
    Utils.Database.collect
      (Pool_database.Label.value pool)
      find_by_experiment_request
      (Pool_common.Id.value id)
  ;;

  let find_by_contact_request =
    let open Caqti_request.Infix in
    {sql|
      WHERE
        contact_id = (SELECT id FROM pool_contacts WHERE user_uuid = UNHEX(REPLACE(?, '-', ''))),
    |sql}
    |> Format.asprintf "%s\n%s" select_sql
    |> Caqti_type.string ->* RepoEntity.t
  ;;

  let find_by_contact pool id =
    Utils.Database.collect
      (Pool_database.Label.value pool)
      find_by_contact_request
      (Pool_common.Id.value id)
  ;;

  let find_experiment_id_of_invitation_request =
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
      FROM
        pool_invitations
      LEFT JOIN pool_experiments
        ON pool_invitations.session_id = pool_experiments.id
      WHERE
        pool_invitations.uuid = UNHEX(REPLACE(?, '-', ''))
    |sql}
    |> Caqti_type.(string ->! string)
  ;;

  let find_experiment_id_of_invitation pool invitation =
    let open Lwt.Infix in
    Utils.Database.find_opt
      (Pool_database.Label.value pool)
      find_experiment_id_of_invitation_request
      (invitation.Entity.id |> Pool_common.Id.value)
    >|= CCOption.map Pool_common.Id.of_string
    >|= CCOption.to_result Pool_common.Message.(NotFound Field.Tenant)
  ;;

  let insert_request =
    let open Caqti_request.Infix in
    {sql|
      INSERT INTO pool_invitations (
        uuid,
        experiment_id,
        contact_id,
        resent_at,
        created_at,
        updated_at
      ) VALUES (
        UNHEX(REPLACE($1, '-', '')),
        (SELECT id FROM pool_experiments WHERE pool_experiments.uuid = UNHEX(REPLACE($2, '-', ''))),
        (SELECT id FROM pool_contacts WHERE pool_contacts.user_uuid = UNHEX(REPLACE($3, '-', ''))),
        $4,
        $5,
        $6
      )
    |sql}
    |> RepoEntity.t ->. Caqti_type.unit
  ;;

  let insert pool =
    Utils.Database.exec (Pool_database.Label.value pool) insert_request
  ;;

  let update_request =
    let open Caqti_request.Infix in
    {sql|
      UPDATE pool_invitations
      SET
        resent_at = $2
      WHERE uuid = UNHEX(REPLACE($1, '-', ''))
    |sql}
    |> RepoEntity.Update.t ->. Caqti_type.unit
  ;;

  let update pool =
    Utils.Database.exec (Pool_database.Label.value pool) update_request
  ;;

  let contact_was_invited_to_experiment_request =
    let open Caqti_request.Infix in
    {sql|
      SELECT pool_invitations.uuid
      FROM
        pool_invitations
      WHERE
        (SELECT id FROM pool_experiments WHERE pool_experiments.uuid = UNHEX(REPLACE($1, '-', ''))),
        (SELECT id FROM pool_contacts WHERE pool_contacts.user_uuid = UNHEX(REPLACE($2, '-', '')))
      LIMIT 1
      |sql}
    |> Format.asprintf "%s\n%s" select_sql
    |> Caqti_type.(tup2 string string) ->! Pool_common.Repo.Id.t
  ;;

  let contact_was_invited_to_experiment pool experiment contact =
    let open Lwt.Infix in
    Utils.Database.find_opt
      (Pool_database.Label.value pool)
      contact_was_invited_to_experiment_request
      ( experiment.Experiment.id |> Pool_common.Id.value
      , Contact.id contact |> Pool_common.Id.value )
    >|= CCOption.is_some
  ;;
end

let contact_to_invitation pool invitation =
  let open Utils.Lwt_result.Infix in
  Contact.find pool invitation.RepoEntity.contact_id >|= to_entity invitation
;;

let find pool id =
  let open Utils.Lwt_result.Infix in
  (* TODO Implement as transaction *)
  Sql.find pool id >>= contact_to_invitation pool
;;

let find_by_experiment pool id =
  let open Lwt.Infix in
  (* TODO Implement as transaction *)
  Sql.find_by_experiment pool id
  >>= Lwt_list.map_s (contact_to_invitation pool)
  |> Lwt.map CCList.all_ok
;;

let find_by_contact pool contact =
  let open Lwt.Infix in
  (* TODO Implement as transaction *)
  contact
  |> Contact.id
  |> Sql.find_by_contact pool
  (* Reload contact from DB, does not allow already made updates of the provided
     contact record *)
  >>= Lwt_list.map_s (contact_to_invitation pool)
  |> Lwt.map CCList.all_ok
;;

let find_experiment_id_of_invitation = Sql.find_experiment_id_of_invitation

let insert pool session_id model =
  model |> of_entity session_id |> Sql.insert pool
;;

let update = Sql.update
let contact_was_invited_to_experiment = Sql.contact_was_invited_to_experiment