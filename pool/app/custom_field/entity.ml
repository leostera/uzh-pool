module Message = Pool_common.Message
module Language = Pool_common.Language
module Answer = Entity_answer

let printer m fmt _ = Format.pp_print_string fmt m

module Id = struct
  include Pool_common.Id
end

module Model = struct
  let go m fmt _ = Format.pp_print_string fmt m

  type t =
    | Contact [@name "contact"] [@printer printer "contact"]
    | Experiment [@name "experiment"] [@printer printer "experiment"]
    | Session [@name "session"] [@printer printer "session"]
  [@@deriving eq, show { with_path = false }, yojson, enum]

  let field = Pool_common.Message.Field.Model

  let read m =
    m |> Format.asprintf "[\"%s\"]" |> Yojson.Safe.from_string |> t_of_yojson
  ;;

  let all : t list =
    CCList.range min max
    |> CCList.map of_enum
    |> CCList.all_some
    |> CCOption.get_exn_or "Models: Could not create list of all models!"
  ;;

  let create s =
    try Ok (read s) with
    | _ -> Error Pool_common.Message.(Invalid field)
  ;;

  let value = show
  let schema () = Pool_common.Utils.schema_decoder create value field
end

module Name = struct
  type name = string [@@deriving eq, show, yojson]

  let value_name n = n

  type t = (Language.t * name) list [@@deriving eq, show, yojson]

  let find_opt lang t = CCList.assoc_opt ~eq:Language.equal lang t

  let create sys_languages names =
    CCList.filter
      (fun lang ->
        CCList.assoc_opt ~eq:Pool_common.Language.equal lang names
        |> CCOption.is_none)
      sys_languages
    |> function
    | [] -> Ok names
    | _ -> Error Pool_common.Message.(AllLanguagesRequired Field.Name)
  ;;
end

module Hint = struct
  type hint = string [@@deriving eq, show, yojson]

  let value_hint h = h

  type t = (Language.t * hint) list [@@deriving eq, show, yojson]

  let find_opt lang t = CCList.assoc_opt ~eq:Language.equal lang t
  let create hints = Ok hints
end

module FieldType = struct
  type t =
    | Number [@name "number"] [@printer printer "number"]
    | Select [@name "select"] [@printer printer "select"]
    | Text [@name "text"] [@printer printer "text"]
  [@@deriving eq, show { with_path = false }, yojson, enum]

  let field = Pool_common.Message.Field.FieldType

  let read m =
    m |> Format.asprintf "[\"%s\"]" |> Yojson.Safe.from_string |> t_of_yojson
  ;;

  let all : t list =
    CCList.range min max
    |> CCList.map of_enum
    |> CCList.all_some
    |> CCOption.get_exn_or "Models: Could not create list of all models!"
  ;;

  let create s =
    try Ok (read s) with
    | _ -> Error Pool_common.Message.(Invalid field)
  ;;

  let value = show
  let schema () = Pool_common.Utils.schema_decoder create value field
end

module Required = struct
  include Pool_common.Model.Boolean

  let schema = schema Pool_common.Message.Field.Required
end

module Disabled = struct
  include Pool_common.Model.Boolean

  let schema = schema Pool_common.Message.Field.Disabled
end

module Admin = struct
  module Hint = struct
    include Pool_common.Model.String

    let field = Message.Field.AdminHint
    let create = create field
    let schema = schema field ?validation:None
  end

  module Overwrite = struct
    include Pool_common.Model.Boolean

    let schema = schema Pool_common.Message.Field.Overwrite
  end

  type t =
    { hint : Hint.t option
    ; overwrite : Overwrite.t
    }
  [@@deriving eq, show]
end

module Validation = struct
  let printer m fmt _ = Format.pp_print_string fmt m

  type raw = string * string [@@deriving show, eq, yojson]
  type raw_list = raw list [@@deriving show, eq, yojson]

  module Ptime = struct
    include Ptime

    let t_of_yojson = Pool_common.Model.Ptime.t_of_yojson
    let yojson_of_t = Pool_common.Model.Ptime.yojson_of_t
  end

  module Text = struct
    let text_min_length = "text_length_min"
    let text_max_length = "text_length_max"

    let schema data =
      let open CCOption in
      CCList.filter_map
        (fun (key, value) ->
          (match key with
           | _ when CCString.equal key text_min_length ->
             value
             |> CCInt.of_string
             >|= fun min str ->
             if CCString.length str < min
             then Error (Message.TextLengthMin min)
             else Ok str
           | _ when CCString.equal key text_max_length ->
             value
             |> CCInt.of_string
             >|= fun max str ->
             if CCString.length str > max
             then Error (Message.TextLengthMax max)
             else Ok str
           | _ -> None)
          |> CCOption.map (fun r -> r, (key, value)))
        data
    ;;

    let all = [ text_min_length, `Number; text_max_length, `Number ]
  end

  module Number = struct
    let number_min = "number_min"
    let number_max = "number_max"

    let schema data =
      let open CCOption in
      CCList.filter_map
        (fun (key, value) ->
          (match key with
           | _ when CCString.equal key number_min ->
             value
             |> CCInt.of_string
             >|= fun min i ->
             if i < min then Error (Message.NumberMin min) else Ok i
           | _ when CCString.equal key number_max ->
             value
             |> CCInt.of_string
             >|= fun max i ->
             if i > max then Error (Message.NumberMax max) else Ok i
           | _ -> None)
          |> CCOption.map (fun r -> r, (key, value)))
        data
    ;;

    let all = [ number_min, `Number; number_max, `Number ]
  end

  let encode_to_yojson t =
    t |> CCList.map (fun (_, raw) -> raw) |> yojson_of_raw_list
  ;;

  let to_strings all m =
    m
    |> CCList.filter_map (fun (_, (key, value)) ->
         CCList.find_opt (fun (k, _) -> CCString.equal k key) all
         |> CCOption.map (CCFun.const (key, value)))
  ;;

  let all =
    let go field_type lst =
      CCList.map (fun (key, input_type) -> key, input_type, field_type) lst
    in
    go FieldType.Number Number.all @ go FieldType.Text Text.all
  ;;
end

type 'a validation =
  (('a -> ('a, Pool_common.Message.error) result) * Validation.raw
  [@equal fun (_, raw1) (_, raw2) -> Validation.equal_raw raw1 raw2])
[@@deriving show, eq]

type 'a custom_field =
  { id : Id.t
  ; model : Model.t
  ; name : Name.t
  ; hint : Hint.t
  ; validation : 'a validation list
  ; required : Required.t
  ; disabled : Disabled.t
  ; admin : Admin.t
  }
[@@deriving eq, show]

module SelectOption = struct
  module Id = struct
    include Pool_common.Id
  end

  type t =
    { id : Id.t
    ; name : Name.t
    }
  [@@deriving eq, show]

  let show_id (m : t) = m.id |> Id.value

  let name lang (t : t) =
    Name.find_opt lang t.name |> CCOption.get_exn_or "Cannot find field name."
  ;;

  let create ?(id = Id.create ()) name = { id; name }
end

type t =
  | Number of int custom_field
  | Select of SelectOption.t custom_field * SelectOption.t list
  | Text of string custom_field
[@@deriving eq, show]

let create
  ?(id = Pool_common.Id.create ())
  ?(select_options = [])
  field_type
  model
  name
  hint
  validation
  required
  disabled
  admin
  =
  let open CCResult in
  match (field_type : FieldType.t) with
  | FieldType.Number ->
    let validation = Validation.Number.schema validation in
    Ok (Number { id; model; name; hint; validation; required; disabled; admin })
  | FieldType.Text ->
    let validation = Validation.Text.schema validation in
    Ok (Text { id; model; name; hint; validation; required; disabled; admin })
  | FieldType.Select ->
    Ok
      (Select
         ( { id; model; name; hint; validation = []; required; disabled; admin }
         , select_options ))
;;

module Write = struct
  type t =
    { id : Id.t
    ; model : Model.t
    ; name : Name.t
    ; hint : Hint.t
    ; validation : Yojson.Safe.t
    ; field_type : FieldType.t
    ; required : Required.t
    ; disabled : Disabled.t
    ; admin : Admin.t
    }
  [@@deriving eq, show]
end

module Public = struct
  type 'a public =
    { id : Id.t
    ; name : Name.t
    ; hint : Hint.t
    ; validation : 'a validation list
    ; required : Required.t
    ; answer : 'a Answer.t option
    }
  [@@deriving eq, show]

  type t =
    | Number of int public
    | Select of SelectOption.t public * SelectOption.t list
    | Text of string public
  [@@deriving eq, show]

  let id (t : t) =
    match t with
    | Number { id; _ } | Select ({ id; _ }, _) | Text { id; _ } -> id
  ;;

  let name_value lang (t : t) =
    match t with
    | Number { name; _ } | Select ({ name; _ }, _) | Text { name; _ } ->
      Name.find_opt lang name |> CCOption.get_exn_or "Cannot find field name."
  ;;

  let hint lang (t : t) =
    match t with
    | Number { hint; _ } | Select ({ hint; _ }, _) | Text { hint; _ } ->
      Hint.find_opt lang hint
  ;;

  let required (t : t) =
    match t with
    | Number { required; _ }
    | Select ({ required; _ }, _)
    | Text { required; _ } -> required
  ;;

  let version (t : t) =
    match t with
    | Number { answer; _ } -> answer |> CCOption.map Answer.version
    | Select ({ answer; _ }, _) -> answer |> CCOption.map Answer.version
    | Text { answer; _ } -> answer |> CCOption.map Answer.version
  ;;

  let answer_id =
    let id a = a |> CCOption.map Answer.id in
    function
    | (Number { answer; _ } : t) -> id answer
    | Select ({ answer; _ }, _) -> id answer
    | Text { answer; _ } -> id answer
  ;;

  let validate value (m : t) =
    let open CCResult.Infix in
    let go rules value =
      CCList.fold_left
        (fun result (rule, _) -> result >>= rule)
        (Ok value)
        rules
    in
    let id = answer_id m in
    let version = version m in
    match m with
    | Number ({ validation; _ } as public) ->
      value
      |> CCInt.of_string
      |> CCOption.to_result Pool_common.Message.(NotANumber value)
      >>= fun i ->
      i
      |> go validation
      >|= Answer.create ?id ?version
      >|= fun a : t -> Number { public with answer = a |> CCOption.pure }
    | Select (public, options) ->
      let value = value |> SelectOption.Id.of_string in
      let selected =
        CCList.find_opt
          (fun option -> SelectOption.Id.equal option.SelectOption.id value)
          options
      in
      selected
      |> CCOption.to_result Pool_common.Message.InvalidOptionSelected
      >|= Answer.create ?id ?version
      >|= fun a : t ->
      Select ({ public with answer = a |> CCOption.pure }, options)
    | Text ({ validation; _ } as public) ->
      value
      |> go validation
      >|= Answer.create ?id ?version
      >|= fun a : t -> Text { public with answer = a |> CCOption.pure }
  ;;

  let to_common_field language m =
    let id = id m in
    let name = name_value language m in
    Pool_common.Message.(Field.CustomHtmx (name, id |> Id.value))
  ;;

  let to_common_hint language m =
    let open CCOption in
    hint language m
    >|= Hint.value_hint
    >|= fun h -> Pool_common.I18n.CustomHtmx h
  ;;
end

let id = function
  | Number { id; _ } | Select ({ id; _ }, _) | Text { id; _ } -> id
;;

let model = function
  | Number { model; _ } | Select ({ model; _ }, _) | Text { model; _ } -> model
;;

let name = function
  | Number { name; _ } | Select ({ name; _ }, _) | Text { name; _ } -> name
;;

let hint = function
  | Number { hint; _ } | Select ({ hint; _ }, _) | Text { hint; _ } -> hint
;;

let required = function
  | Number { required; _ } | Select ({ required; _ }, _) | Text { required; _ }
    -> required
;;

let disabled = function
  | Number { disabled; _ } | Select ({ disabled; _ }, _) | Text { disabled; _ }
    -> disabled
;;

let admin = function
  | Number { admin; _ } | Select ({ admin; _ }, _) | Text { admin; _ } -> admin
;;

let field_type = function
  | Number _ -> FieldType.Number
  | Select _ -> FieldType.Select
  | Text _ -> FieldType.Text
;;

let validation_strings =
  let open Validation in
  function
  | Number { validation; _ } -> validation |> to_strings Number.all
  | Select _ -> []
  | Text { validation; _ } -> validation |> to_strings Text.all
;;

let validation_to_yojson = function
  | Number { validation; _ } -> Validation.encode_to_yojson validation
  | Select _ -> "[]" |> Yojson.Safe.from_string
  | Text { validation; _ } -> Validation.encode_to_yojson validation
;;

let boolean_fields = Pool_common.Message.Field.[ Required; Disabled; Overwrite ]
