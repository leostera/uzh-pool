module Token : sig
  type t

  val equal : t -> t -> bool
  val pp : Format.formatter -> t -> unit
  val show : t -> string
  val create : string -> t
  val value : t -> string
end

module VerifiedAt : sig
  type t

  val equal : t -> t -> bool
  val pp : Format.formatter -> t -> unit
  val show : t -> string
  val value : t -> Ptime.t
  val create : Ptime.t -> t
  val create_now : unit -> t
end

type email_unverified =
  { address : Pool_user.EmailAddress.t
  ; user : Sihl_user.t
  ; token : Token.t
  ; created_at : Pool_common.CreatedAt.t
  ; updated_at : Pool_common.UpdatedAt.t
  }

type email_verified =
  { address : Pool_user.EmailAddress.t
  ; user : Sihl_user.t
  ; verified_at : VerifiedAt.t
  ; created_at : Pool_common.CreatedAt.t
  ; updated_at : Pool_common.UpdatedAt.t
  }

type unverified
type verified

val equal_email_unverified : email_unverified -> email_unverified -> bool
val equal_email_verified : email_verified -> email_verified -> bool
val pp_email_unverified : Format.formatter -> email_unverified -> unit
val pp_email_verified : Format.formatter -> email_verified -> unit
val show_email_unverified : email_unverified -> string
val show_email_verified : email_verified -> string

type _ t =
  | Unverified : email_unverified -> unverified t
  | Verified : email_verified -> verified t

val equal : 'email t -> 'email t -> bool
val pp : Format.formatter -> 'email t -> unit
val show : 'state t -> string
val token : unverified t -> string
val verify : unverified t -> verified t
val address : 'email t -> Pool_user.EmailAddress.t
val user_id : 'email t -> Pool_common.Id.t
val user_is_confirmed : 'email t -> bool
val create : Pool_user.EmailAddress.t -> Sihl_user.t -> Token.t -> unverified t

val find_unverified_by_user
  :  Pool_database.Label.t
  -> Pool_common.Id.t
  -> (unverified t, Pool_common.Message.error) result Lwt.t

val find_verified_by_user
  :  Pool_database.Label.t
  -> Pool_common.Id.t
  -> (verified t, Pool_common.Message.error) result Lwt.t

val find_unverified_by_address
  :  Pool_database.Label.t
  -> Pool_user.EmailAddress.t
  -> (unverified t, Pool_common.Message.error) result Lwt.t

val delete_unverified_by_user
  :  Pool_database.Label.t
  -> Pool_common.Id.t
  -> unit Lwt.t

val create_token
  :  Pool_database.Label.t
  -> Pool_user.EmailAddress.t
  -> Token.t Lwt.t

module SmtpAuth : sig
  module Id : module type of Pool_common.Id
  module Label : Pool_common.Model.StringSig
  module Server : Pool_common.Model.StringSig
  module Port : Pool_common.Model.IntegerSig
  module Username : Pool_common.Model.StringSig
  module Password : Pool_common.Model.StringSig

  module RepoEntity : sig
    module Id : sig
      val t : Id.t Caqti_type.t
    end
  end

  module Mechanism : sig
    type t =
      | PLAIN
      | LOGIN

    val equal : t -> t -> bool
    val pp : Format.formatter -> t -> unit
    val show : t -> string
    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
    val t_of_yojson : Yojson.Safe.t -> t
    val yojson_of_t : t -> Yojson.Safe.t
    val read : string -> t
    val all : t list

    val schema
      :  unit
      -> (Pool_common.Message.error, t) Pool_common.Utils.PoolConformist.Field.t
  end

  module Protocol : sig
    type t =
      | STARTTLS
      | SSL_TLS

    val equal : t -> t -> bool
    val pp : Format.formatter -> t -> unit
    val show : t -> string
    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
    val t_of_yojson : Yojson.Safe.t -> t
    val yojson_of_t : t -> Yojson.Safe.t
    val read : string -> t
    val all : t list

    val schema
      :  unit
      -> (Pool_common.Message.error, t) Pool_common.Utils.PoolConformist.Field.t
  end

  module Default : sig
    include Pool_common.Model.BooleanSig
  end

  type t =
    { id : Id.t
    ; label : Label.t
    ; server : Server.t
    ; port : Port.t
    ; username : Username.t option
    ; mechanism : Mechanism.t
    ; protocol : Protocol.t
    ; default : Default.t
    }

  type update_password =
    { id : Id.t
    ; password : Password.t option
    }

  val pp : Format.formatter -> t -> unit
  val equal : t -> t -> bool

  module Write : sig
    type t =
      { id : Id.t
      ; label : Label.t
      ; server : Server.t
      ; port : Port.t
      ; username : Username.t option
      ; password : Password.t option
      ; mechanism : Mechanism.t
      ; protocol : Protocol.t
      ; default : Default.t
      }

    val create
      :  ?id:Id.t
      -> Label.t
      -> Server.t
      -> Port.t
      -> Username.t option
      -> Password.t option
      -> Mechanism.t
      -> Protocol.t
      -> Default.t
      -> (t, Pool_common.Message.error) result
  end

  val find
    :  Pool_database.Label.t
    -> Id.t
    -> (t, Pool_common.Message.error) Lwt_result.t

  val find_by_label : Pool_database.Label.t -> Label.t -> t option Lwt.t

  (* TODO: Can probably be removed *)
  val find_full_by_label
    :  Pool_database.Label.t
    -> (Write.t, Pool_common.Message.error) Lwt_result.t

  val find_default
    :  Pool_database.Label.t
    -> (t, Pool_common.Message.error) Lwt_result.t

  val find_default_opt : Pool_database.Label.t -> t option Lwt.t
  val find_all : Pool_database.Label.t -> t list Lwt.t
end

type job =
  { email : Sihl.Contract.Email.t
  ; smtp_auth_id : SmtpAuth.Id.t option
  }

module Service : sig
  module Queue : Sihl.Contract.Queue.Sig

  module Cache : sig
    val clear : unit -> unit
  end

  module Smtp : sig
    type prepared =
      { sender : string
      ; reply_to : string
      ; recipients : Letters.recipient list
      ; subject : string
      ; body : Letters.body
      ; config : Letters.Config.t
      }

    val inbox : unit -> Sihl_email.t list
    val clear_inbox : unit -> unit

    val prepare
      :  Pool_database.Label.t
      -> ?smtp_auth_id:SmtpAuth.Id.t
      -> Sihl_email.t
      -> prepared Lwt.t
  end

  module Job : sig
    val send : job Sihl_queue.job
  end

  val default_sender_of_pool
    :  Pool_database.Label.t
    -> Pool_user.EmailAddress.t Lwt.t

  val intercept_prepare : job -> (job, Pool_common.Message.error) result

  val dispatch
    :  Pool_database.Label.t
    -> Entity.email * SmtpAuth.Id.t option
    -> unit Lwt.t

  val dispatch_all
    :  Pool_database.Label.t
    -> (Entity.email * SmtpAuth.Id.t option) list
    -> unit Lwt.t

  val lifecycle : Sihl.Container.lifecycle
  val register : unit -> Sihl.Container.Service.t
end

module Guard : sig
  module Access : sig
    module Smtp : sig
      val index : Guard.ValidationSet.t
      val create : Guard.ValidationSet.t
      val read : SmtpAuth.Id.t -> Guard.ValidationSet.t
      val update : SmtpAuth.Id.t -> Guard.ValidationSet.t
      val delete : SmtpAuth.Id.t -> Guard.ValidationSet.t
    end
  end
end

type verification_event =
  | Created of Pool_user.EmailAddress.t * Token.t * Pool_common.Id.t
  | EmailVerified of unverified t

val handle_verification_event
  :  Pool_database.Label.t
  -> verification_event
  -> unit Lwt.t

val equal_verification_event : verification_event -> verification_event -> bool
val pp_verification_event : Format.formatter -> verification_event -> unit

type event =
  | Sent of (Sihl_email.t * SmtpAuth.Id.t option)
  | BulkSent of (Sihl_email.t * SmtpAuth.Id.t option) list
  | SmtpCreated of SmtpAuth.Write.t
  | SmtpEdited of SmtpAuth.t
  | SmtpPasswordEdited of SmtpAuth.update_password

val handle_event : Pool_database.Label.t -> event -> unit Lwt.t
val equal_event : event -> event -> bool
val pp_event : Format.formatter -> event -> unit
val show_event : event -> string
val verification_event_name : verification_event -> string
val sent : Sihl_email.t * SmtpAuth.Id.t option -> event
val bulksent : (Sihl_email.t * SmtpAuth.Id.t option) list -> event
