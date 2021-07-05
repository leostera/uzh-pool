include Entity
include Event

let find_by_participant _ = Sihl.todo
let find_by_user _ = Sihl.todo

type list_recruiters =
  { limit : int
  ; offset : int
  }

type handle_list_recruiters = list_recruiters -> Sihl.User.t list Lwt.t

type list_tenants =
  { limit : int
  ; offset : int
  ; fitler : string
  }

type handle_tenants = list_tenants -> tenant list Lwt.t
