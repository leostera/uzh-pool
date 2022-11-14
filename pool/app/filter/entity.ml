module Helper = struct
  let key_string = "key"
  let operator_string = "operator"
  let value_string = "value"
end

let read of_yojson yojson =
  yojson
  |> Yojson.Safe.to_string
  |> Format.asprintf "[%s]"
  |> Yojson.Safe.from_string
  |> of_yojson
;;

let print m fmt _ = Format.pp_print_string fmt m

type single_val =
  | Bool of bool [@printer print "bool"] [@name "bool"]
  | Date of Ptime.t [@printer print "date"] [@name "date"]
  | Nr of float [@printer print "nr"] [@name "nr"]
  | Option of Custom_field.SelectOption.Id.t [@printer print "option"]
      [@name "option"]
  | Str of string [@printer print "str"] [@name "str"]
[@@deriving show { with_path = false }, eq]

type value =
  | Single of single_val [@printer print "single"] [@name "single"]
  | Lst of single_val list [@printer print "list"] [@name "list"]
[@@deriving show { with_path = false }, eq, variants]

let single_value_of_yojson (yojson : Yojson.Safe.t) =
  let error = Pool_common.Message.(Invalid Field.Value) in
  match yojson with
  | `Assoc [ (key, value) ] ->
    (match key, value with
     | "bool", `Bool b -> Ok (Bool b)
     | "date", `String str ->
       str
       |> Ptime.of_rfc3339
       |> CCResult.map2 (fun (date, _, _) -> Date date) (fun _ -> error)
     | "nr", `Float n -> Ok (Nr n)
     | "nr", `Int n -> Ok (Nr (CCInt.to_float n))
     | "option", `String id ->
       Ok (Option (Custom_field.SelectOption.Id.of_string id))
     | "str", `String str -> Ok (Str str)
     | _ -> Error error)
  | _ -> Error error
;;

let value_of_yojson (yojson : Yojson.Safe.t) =
  let open CCResult in
  let error = Pool_common.Message.(Invalid Field.Value) in
  match yojson with
  | `Assoc [ (key, value) ] ->
    (match key, value with
     | "list", `List values ->
       values |> CCList.map single_value_of_yojson |> CCList.all_ok >|= lst
     | _ -> single_value_of_yojson yojson >|= single)
  | _ -> Error error
;;

let to_assoc key value = `Assoc [ key, value ]

let yojson_of_single_val value =
  let to_assoc = to_assoc (value |> show_single_val) in
  to_assoc
  @@
  match value with
  | Bool b -> `Bool b
  | Date ptime -> `String (Ptime.to_rfc3339 ptime)
  | Nr n -> `Float n
  | Option id -> `String (Custom_field.SelectOption.Id.value id)
  | Str str -> `String str
;;

let yojson_of_value m =
  match m with
  | Single single -> single |> yojson_of_single_val
  | Lst values ->
    let value_list = `List (CCList.map yojson_of_single_val values) in
    to_assoc (m |> show_value) value_list
;;

module Key = struct
  type input_type =
    | Bool [@printer print "bool"]
    | Date [@printer print "date"]
    | Nr [@printer print "nr"]
    | Str [@printer print "str"]
    | Select of Custom_field.SelectOption.t list [@printer print "option"]
  [@@deriving show]

  type hardcoded =
    | Email [@printer print "email"] [@name "email"]
    | Name [@printer print "name"] [@name "name"]
    | Paused [@printer print "paused"] [@name "paused"]
    | Verified [@printer print "verified"] [@name "verified"]
    | VerifiedAt [@printer print "verified_at"] [@name "verified_at"]
  [@@deriving show { with_path = false }, eq, yojson, variants]

  type human =
    | CustomField of Custom_field.t
    | Hardcoded of hardcoded
  [@@deriving show { with_path = false }, eq, variants]

  type t =
    | CustomField of Custom_field.Id.t
    | Hardcoded of hardcoded
  [@@deriving show { with_path = false }, eq]

  let read_hardcoded yojson =
    try Some (yojson |> read hardcoded_of_yojson) with
    | _ -> None
  ;;

  let to_human key_list m =
    let find_in_keys key_id =
      CCList.find_opt
        (fun key ->
          match (key : human) with
          | Hardcoded _ -> false
          | CustomField f -> Custom_field.(Id.equal (id f) key_id))
        key_list
    in
    match (m : t) with
    | Hardcoded h -> Some (Hardcoded h : human)
    | CustomField id -> id |> find_in_keys
  ;;

  let of_yojson : Yojson.Safe.t -> (t, Pool_common.Message.error) result =
   fun yojson ->
    match read_hardcoded yojson with
    | Some h -> Ok (Hardcoded h)
    | None ->
      (* The "validate_filter" function will check, if the id belongs to an
         existing custom field *)
      (match yojson with
       | `String id -> Ok (CustomField (id |> Custom_field.Id.of_string))
       | _ -> Error Pool_common.Message.(Invalid Field.Key))
 ;;

  let to_yojson (m : t) =
    (match m with
     | Hardcoded h -> h |> show_hardcoded
     | CustomField id -> id |> Custom_field.Id.value)
    |> fun str -> `String str
  ;;

  let read m =
    try Some (`String m |> read hardcoded_of_yojson) with
    | _ -> None
  ;;

  let human_to_label language human =
    let open CCString in
    match (human : human) with
    | Hardcoded h ->
      show_hardcoded h |> replace ~sub:"_" ~by:" " |> capitalize_ascii
    | CustomField f -> Custom_field.(f |> name_value language)
  ;;

  let human_to_value human =
    match (human : human) with
    | Hardcoded h -> show_hardcoded h
    | CustomField f -> Custom_field.(f |> id |> Id.value)
  ;;

  let hardcoded_to_sql = function
    | Email -> "user_users.email"
    | Name -> "user_users.name"
    | Paused -> "pool_contacts.paused"
    | Verified ->
      "pool_contacts.verified" (* TODO: This column does not exists*)
    | VerifiedAt -> "pool_contacts.verified"
  ;;

  let type_of_hardcoded m : input_type =
    match m with
    | Email -> Str
    | Name -> Str
    | Paused -> Bool
    | Verified -> Bool
    | VerifiedAt -> Date
  ;;

  let type_of_custom_field m : input_type =
    let open Custom_field in
    match m with
    | Boolean _ -> Bool
    | Number _ -> Nr
    | MultiSelect (_, options) -> Select options
    | Select (_, options) -> Select options
    | Text _ -> Str
  ;;

  let type_of_key m : input_type =
    match (m : human) with
    | CustomField c -> type_of_custom_field c
    | Hardcoded h -> type_of_hardcoded h
  ;;

  let validate_value (key_list : human list) (m : t) value =
    let error =
      Pool_common.Message.(FilterNotCompatible (Field.Value, Field.Key))
    in
    let open CCResult in
    let validate_single_value input_type value =
      match[@warning "-4"] value, input_type with
      | (Bool _ : single_val), (Bool : input_type)
      | Date _, Date
      | Nr _, Nr
      | Str _, Str -> Ok ()
      | Option selected, Select options ->
        CCList.find_opt
          (fun option ->
            Custom_field.SelectOption.(Id.equal option.id selected))
          options
        |> CCOption.to_result error
        >|= CCFun.const ()
      | _ -> Error error
    in
    let validate_value value input_type =
      match value with
      | Single v -> validate_single_value input_type v
      | Lst lst ->
        lst
        |> CCList.map (validate_single_value input_type)
        |> CCList.all_ok
        >|= CCFun.const ()
    in
    match m with
    | Hardcoded v -> v |> type_of_hardcoded |> validate_value value
    | CustomField field_id ->
      let* custom_field =
        CCList.find_map
          (fun (key : human) ->
            match key with
            | Hardcoded _ -> None
            | CustomField field ->
              if Custom_field.(Id.equal (id field) field_id)
              then Some field
              else None)
          key_list
        |> CCOption.to_result Pool_common.Message.(Invalid Field.Key)
      in
      let input_type = type_of_custom_field custom_field in
      validate_value value input_type
  ;;

  let all_hardcoded : hardcoded list =
    [ Email; Name; Paused; Verified; VerifiedAt ]
  ;;
end

module Operator = struct
  type t =
    | Less [@printer print "less"] [@name "less"]
    | LessEqual [@printer print "less_equal"] [@name "less_equal"]
    | Greater [@printer print "greater"] [@name "greater"]
    | GreaterEqual [@printer print "greater_equal"] [@name "greater_equal"]
    | Equal [@printer print "equal"] [@name "equal"]
    | NotEqual [@printer print "not_equal"] [@name "not_equal"]
    | Like [@printer print "like"] [@name "like"]
    | ContainsSome [@printer print "contains_some"] [@name "contains_some"]
    | ContainsNone [@printer print "contains_none"] [@name "contains_none"]
    | ContainsAll [@printer print "contains_all"] [@name "contains_all"]
  [@@deriving show { with_path = false }, eq, enum, yojson]

  let input_type_to_operator =
    let open Key in
    function
    | Key.Bool -> [ Equal; NotEqual ]
    | Str -> [ Equal; NotEqual; Like ]
    | Date | Nr -> [ Equal; NotEqual; Greater; GreaterEqual; Less; LessEqual ]
    | Select _ -> [ Equal; NotEqual ]
  ;;

  let of_string m =
    try Ok (`String m |> t_of_yojson) with
    | _ -> Error Pool_common.Message.(Invalid Field.Operator)
  ;;

  let of_yojson yojson =
    try Ok (yojson |> read t_of_yojson) with
    | _ -> Error Pool_common.Message.(Invalid Field.Operator)
  ;;

  let to_yojson m = `String (m |> show)

  let to_sql = function
    | Less -> "<"
    | LessEqual -> "<="
    | Greater -> ">"
    | GreaterEqual -> ">="
    | Equal -> "="
    | NotEqual -> "<>"
    | Like -> "LIKE"
    | ContainsSome -> "CONTAINS" (* TODO *)
    | ContainsNone -> "CONTAINS" (* TODO *)
    | ContainsAll -> "CONTAINS"
  ;;

  let validate (key : Key.t) operator =
    match key with
    | Key.Hardcoded k ->
      let available_operators =
        k |> Key.type_of_hardcoded |> input_type_to_operator
      in
      if CCList.mem ~eq:equal operator available_operators
      then Ok ()
      else Error Pool_common.Message.(FilterNotCompatible Field.(Operator, Key))
    | Key.CustomField _ -> Ok ()
  ;;
end

module Predicate = struct
  type t =
    { key : Key.t
    ; operator : Operator.t
    ; value : value
    }
  [@@deriving eq]

  type human =
    { key : Key.human option
    ; operator : Operator.t option
    ; value : value option
    }
  [@@deriving eq]

  let create key operator value : t = { key; operator; value }
  let create_human ?key ?operator ?value () : human = { key; operator; value }

  let validate : t -> Key.human list -> (t, Pool_common.Message.error) result =
   fun ({ key; operator; value } as m) key_list ->
    let open CCResult in
    let* () = Key.validate_value key_list key value in
    let* () = Operator.validate key operator in
    Ok m
 ;;

  let t_of_yojson (yojson : Yojson.Safe.t) =
    let open Pool_common in
    let open Helper in
    let to_result field = CCOption.to_result Message.(Invalid field) in
    match yojson with
    | `Assoc assoc ->
      let open CCResult in
      let go key field of_yojson =
        assoc
        |> CCList.assoc_opt ~eq:CCString.equal key
        |> to_result field
        >>= of_yojson
      in
      let* key = go key_string Message.Field.Key Key.of_yojson in
      let* operator =
        go operator_string Message.Field.Operator Operator.of_yojson
      in
      let* value = go value_string Message.Field.Value value_of_yojson in
      Ok (create key operator value)
    | _ -> Error Pool_common.Message.(Invalid Field.Predicate)
  ;;

  let yojson_of_t ({ key; operator; value } : t) =
    let key = Key.to_yojson key in
    let operator = Operator.to_yojson operator in
    let value = yojson_of_value value in
    `Assoc
      Helper.[ key_string, key; operator_string, operator; value_string, value ]
  ;;
end

type filter =
  | And of filter list [@printer print "and"] [@name "and"]
  | Or of filter list [@printer print "or"] [@name "or"]
  | Not of filter [@printer print "not"] [@name "not"]
  | Pred of Predicate.t [@printer print "pred"] [@name "pred"]
[@@deriving show { with_path = false }, variants, eq]

let rec yojson_of_filter (f : filter) : Yojson.Safe.t =
  (match f with
   | And filters -> `List (CCList.map yojson_of_filter filters)
   | Or filters -> `List (CCList.map yojson_of_filter filters)
   | Not f -> f |> yojson_of_filter
   | Pred p -> Predicate.yojson_of_t p)
  |> fun pred -> `Assoc [ f |> show_filter, pred ]
;;

let rec filter_of_yojson json =
  let error = Pool_common.Message.(Invalid Field.Filter) in
  let open CCResult in
  match json with
  | `Assoc [ (key, filter) ] ->
    (match key, filter with
     | "and", `List filters ->
       filters
       |> CCList.map filter_of_yojson
       |> CCList.all_ok
       >|= fun lst -> And lst
     | "or", `List filters ->
       filters
       |> CCList.map filter_of_yojson
       |> CCList.all_ok
       >|= fun lst -> Or lst
     | "not", f -> f |> filter_of_yojson >|= not
     | "pred", p -> p |> Predicate.t_of_yojson >|= pred
     | _ -> Error error)
  | _ -> Error error
;;

let filter_of_string str = str |> Yojson.Safe.from_string |> filter_of_yojson

let rec validate_filter key_list m =
  let open CCResult in
  let validate_list fnc filters =
    filters |> CCList.map (validate_filter key_list) |> CCList.all_ok >|= fnc
  in
  match m with
  | And filters -> validate_list (fun lst -> And lst) filters
  | Or filters -> validate_list (fun lst -> Or lst) filters
  | Not f -> validate_filter key_list f >|= not
  | Pred p -> Predicate.validate p key_list >|= pred
;;

type t =
  { id : Pool_common.Id.t
  ; filter : filter (* TODO: Rename to predicate or something else *)
  ; created_at : Ptime.t
  ; updated_at : Ptime.t
  }
[@@deriving eq, show]

let create ?(id = Pool_common.Id.create ()) filter =
  { id
  ; filter
  ; created_at = Pool_common.CreatedAt.create ()
  ; updated_at = Pool_common.UpdatedAt.create ()
  }
;;