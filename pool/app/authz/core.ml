type thing =
  | System
  | Tenant
  | Tenant_recruiting
  | Location
  | Experiment
  | Experiment_session
  | Participant

let thing_eq t1 t2 =
  match t1, t2 with
  | System, System -> true
  | Tenant, Tenant -> true
  | Tenant_recruiting, Tenant_recruiting -> true
  | Location, Location -> true
  | Experiment, Experiment -> true
  | Experiment_session, Experiment_session -> true
  | _ -> false
;;

type permission =
  | Create of thing
  | Read of (thing * string option)
  | Update of (thing * string option)
  | Destroy of (thing * string option)
  | Manage of (thing * string option)

let permission_eq p1 p2 =
  match p1, p2 with
  | Create t1, Create t2 -> thing_eq t1 t2
  | Read (t1, id1), Read (t2, id2) ->
    thing_eq t1 t2 && Option.equal String.equal id1 id2
  | Update (t1, id1), Update (t2, id2) ->
    thing_eq t1 t2 && Option.equal String.equal id1 id2
  | Destroy (t1, id1), Destroy (t2, id2) ->
    thing_eq t1 t2 && Option.equal String.equal id1 id2
  | Manage (t1, id1), Manage (t2, id2) ->
    thing_eq t1 t2 && Option.equal String.equal id1 id2
  | _ -> false
;;

let explode_permission = function
  | Manage (thing, id) ->
    [ Create thing
    ; Read (thing, id)
    ; Update (thing, id)
    ; Destroy (thing, id)
    ; Manage (thing, id)
    ]
  | other -> [ other ]
;;

(* Default roles *)

let root =
  [ Manage (Participant, None)
  ; Manage (Tenant, None)
  ; Manage (Tenant_recruiting, None)
  ; Manage (Location, None)
  ; Manage (Experiment, None)
  ; Manage (Experiment_session, None)
  ; Manage (System, None)
  ]
;;

let operator tenant_id = [ Manage (Tenant, Some tenant_id) ]
let recruiter tenant_id = [ Manage (Tenant_recruiting, Some tenant_id) ]
let location_manager location_id = [ Read (Location, Some location_id) ]
let experimenter experiment_id = [ Manage (Experiment, Some experiment_id) ]

let assistant experiment_id =
  [ Read (Experiment, Some experiment_id)
  ; Update (Experiment, Some experiment_id)
  ]
;;

let participant user_id =
  [ Create Participant
  ; Read (Participant, Some user_id)
  ; Update (Participant, Some user_id)
  ]
;;
