open Entity
module RepoPerson = Repo_person
module Database = Pool_database

let extract : type a. a Entity.carrier -> a Entity.t Caqti_type.t * string =
  let open Repo_person in
  let open Stringify in
  function
  | AssistantC -> assistant, person `Assistant
  | ExperimenterC -> experimenter, person `Experimenter
  | LocationManagerC -> location_manager, person `LocationManager
  | RecruiterC -> recruiter, person `Recruiter
  | OperatorC -> operator, person `Operator
;;

module Sql = struct
  let update_request =
    let open Caqti_request.Infix in
    {sql|
      UPDATE pool_person
        SET
          role = $1,
          created_at = $3,
          updated_at = $4
        WHERE sihl_user_uuid = UNHEX(REPLACE($2, '-', ''))
    |sql}
    |> RepoPerson.Write.caqti ->. Caqti_type.unit
  ;;

  let update pool t =
    Utils.Database.exec
      (Database.Label.value pool)
      update_request
      (RepoPerson.Write.extract t)
  ;;

  let select_from_persons_sql where_fragment =
    let select_from =
      {sql|
        SELECT
          pool_person.role,
          LOWER(CONCAT(
            SUBSTR(HEX(user_users.uuid), 1, 8), '-',
            SUBSTR(HEX(user_users.uuid), 9, 4), '-',
            SUBSTR(HEX(user_users.uuid), 13, 4), '-',
            SUBSTR(HEX(user_users.uuid), 17, 4), '-',
            SUBSTR(HEX(user_users.uuid), 21)
          )),
          user_users.email,
          user_users.username,
          user_users.name,
          user_users.given_name,
          user_users.password,
          user_users.status,
          user_users.admin,
          user_users.confirmed,
          user_users.created_at,
          user_users.updated_at,
          pool_person.created_at,
          pool_person.updated_at
        FROM pool_person
        INNER JOIN user_users ON pool_person.sihl_user_uuid = user_users.uuid
      |sql}
    in
    Format.asprintf "%s %s" select_from where_fragment
  ;;

  let find_all_by_role_request caqti_type =
    let open Caqti_request.Infix in
    {sql|
      WHERE pool_person.role = ?
      AND user_users.confirmed = 1
    |sql}
    |> select_from_persons_sql
    |> Caqti_type.string ->* caqti_type
  ;;

  let find_all_by_role pool role =
    let caqti_type, role_val = extract role in
    Utils.Database.collect
      (Database.Label.value pool)
      (find_all_by_role_request caqti_type)
      role_val
  ;;

  let find_request caqti_type =
    let open Caqti_request.Infix in
    {sql|
      WHERE user_users.uuid = UNHEX(REPLACE(?, '-', ''))
      AND pool_person.role = ?
      AND user_users.confirmed = 1
    |sql}
    |> select_from_persons_sql
    |> Caqti_type.(tup2 Pool_common.Repo.Id.t string) ->! caqti_type
  ;;

  let find pool role id =
    let open Lwt.Infix in
    let caqti_type, role_val = extract role in
    Utils.Database.find_opt
      (Database.Label.value pool)
      (find_request caqti_type)
      (id, role_val)
    >|= CCOption.to_result Pool_common.Message.(NotFound Field.Admin)
  ;;

  let find_role_by_user_request =
    let open Caqti_request.Infix in
    {sql|
      SELECT
        pool_person.role
      FROM pool_person
      INNER JOIN user_users ON pool_person.sihl_user_uuid = user_users.uuid
      AND user_users.uuid = UNHEX(REPLACE(?, '-', ''))
    |sql}
    |> Caqti_type.(string ->! string)
  ;;

  let find_role_by_user pool user =
    let open Lwt_result.Infix in
    Utils.Database.find_opt
      (Database.Label.value pool)
      find_role_by_user_request
      user.Sihl.Contract.User.id
    |> Lwt.map (CCOption.to_result Pool_common.Message.(NotFound Field.Admin))
    >>= fun role -> role |> Stringify.person_from_string |> Lwt_result.lift
  ;;

  let insert_sql =
    {sql|
      INSERT INTO pool_person (
        role,
        sihl_user_uuid,
        created_at,
        updated_at
      ) VALUES (
        ?,
        UNHEX(REPLACE(?, '-', '')),
        ?,
        ?
      )
    |sql}
  ;;

  let insert_request =
    let open Caqti_request.Infix in
    insert_sql |> RepoPerson.Write.caqti ->. Caqti_type.unit
  ;;

  let insert pool (t : 'a t) =
    Utils.Database.exec
      (Database.Label.value pool)
      insert_request
      (RepoPerson.Write.extract t)
  ;;
end

let find = Sql.find
let find_role_by_user = Sql.find_role_by_user
let find_all_by_role = Sql.find_all_by_role
let insert = Sql.insert
let update = Sql.update

let find_any_admin_by_user_id pool id =
  let open Lwt_result.Infix in
  let find_admin carrier = find pool carrier id >|= fun m -> Any m in
  let user =
    Service.User.find_opt
      ~ctx:(Pool_tenant.to_ctx pool)
      (Pool_common.Id.value id)
    |> Lwt.map (CCOption.to_result Pool_common.Message.(NotFound Field.User))
  in
  user
  >>= find_role_by_user pool
  >>= function
  | `Assistant -> find_admin AssistantC
  | `Experimenter -> find_admin ExperimenterC
  | `LocationManager -> find_admin LocationManagerC
  | `Recruiter -> find_admin RecruiterC
  | `Operator -> find_admin OperatorC
  | _ ->
    Pool_common.(
      Message.(Invalid Field.Role) |> Utils.error_to_string Language.En)
    |> failwith
;;
