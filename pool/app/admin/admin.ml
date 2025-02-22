open CCFun.Infix
open Utils.Lwt_result.Infix
include Event
include Entity

let find = Repo.find
let find_all = Repo.find_all

let find_all_id_with_role ?exclude pool role =
  Guard.Persistence.ActorRole.find_actors_by_role
    ~ctx:(Pool_database.to_ctx pool)
    ?exclude
    role
  ||> CCList.map CCFun.(Guard.Uuid.Actor.to_string %> Pool_common.Id.of_string)
;;

let find_all_with_role ?exclude pool role =
  find_all_id_with_role ?exclude pool role >|> Repo.find_multiple pool
;;

let find_all_with_roles ?exclude pool roles =
  Lwt_list.map_s (find_all_id_with_role ?exclude pool) roles
  ||> CCList.flatten %> CCList.uniq ~eq:Id.equal
  >|> Repo.find_multiple pool
;;

let user_is_admin pool (user : Sihl_user.t) =
  if Sihl_user.is_admin user
  then (
    let%lwt admin = find pool (Pool_common.Id.of_string user.Sihl_user.id) in
    Lwt.return @@ CCResult.is_ok admin)
  else Lwt.return_false
;;

module Guard = Entity_guard

module Repo = struct
  module Entity = Repo_entity

  let select_imported_admins_sql = Repo.Sql.select_imported_admins_sql
end
