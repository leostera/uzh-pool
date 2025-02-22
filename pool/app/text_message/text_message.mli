module Content : sig
  type t

  val value : t -> string
end

type t

val create : Pool_user.CellPhone.t -> Pool_tenant.Title.t -> Content.t -> t

val render_and_create
  :  Pool_user.CellPhone.t
  -> Pool_tenant.Title.t
  -> string * (string * string) list
  -> t

module Service : sig
  val register : unit -> Sihl.Container.Service.t

  val test_api_key
    :  tags:Logs.Tag.set
    -> Pool_tenant.GtxApiKey.t
    -> Pool_user.CellPhone.t
    -> Pool_tenant.Title.t
    -> (Pool_tenant.GtxApiKey.t, Pool_common.Message.error) result Lwt.t

  module Job : sig
    val send : t Sihl_queue.job
  end

  val send : Pool_database.Label.t -> t -> unit Lwt.t
end

type event =
  | Sent of t
  | BulkSent of t list

val equal_event : event -> event -> bool
val pp_event : Format.formatter -> event -> unit
val show_event : event -> string
val handle_event : Pool_database.Label.t -> event -> unit Lwt.t
val sent : t -> event
val bulksent : t list -> event
