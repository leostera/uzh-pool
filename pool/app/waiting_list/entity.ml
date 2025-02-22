module AdminComment = struct
  type t = string [@@deriving eq, show]

  let create m = m
  let value m = m

  let schema () =
    Pool_common.(
      Utils.schema_decoder
        (fun m -> Ok (m |> create))
        value
        Message.Field.AdminComment)
  ;;
end

type t =
  { id : Pool_common.Id.t
  ; contact : Contact.t
  ; experiment : Experiment.t
  ; admin_comment : AdminComment.t option
  ; created_at : Pool_common.CreatedAt.t
  ; updated_at : Pool_common.UpdatedAt.t
  }
[@@deriving eq, show]

let create ?(id = Pool_common.Id.create ()) contact experiment admin_comment =
  { id
  ; contact
  ; experiment
  ; admin_comment
  ; created_at = Pool_common.CreatedAt.create ()
  ; updated_at = Pool_common.UpdatedAt.create ()
  }
;;

module ExperimentList = struct
  type waiting_list_entry =
    { id : Pool_common.Id.t
    ; contact : Contact.Preview.t
    ; admin_comment : AdminComment.t option
    ; created_at : Pool_common.CreatedAt.t
    ; updated_at : Pool_common.UpdatedAt.t
    }
  [@@deriving eq, show]

  type t =
    { experiment : Experiment.t
    ; waiting_list_entries : waiting_list_entry list
    }
  [@@deriving eq, show]
end

let searchable_by = Contact.searchable_by

let sortable_by =
  searchable_by
  @ (Pool_common.Message.[ Field.CreatedAt, "pool_waiting_list.created_at" ]
     |> Query.Column.create_list)
;;
