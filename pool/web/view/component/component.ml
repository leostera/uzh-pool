module HttpUtils = Http_utils
open Tyxml.Html

let icon icon_type =
  (match icon_type with
  | `CalendarOutline -> "calendar-outline"
  | `Calendar -> "calendar"
  | `CreateOutline -> "create-outline"
  | `Create -> "create"
  | `EarthOutline -> "earth-outline"
  | `Earth -> "earth"
  | `LeafOutline -> "leaf-outline"
  | `Leaf -> "leaf"
  | `LocationOutline -> "location-outline"
  | `Location -> "location"
  | `MailOutline -> "mail-outline"
  | `Mail -> "mail"
  | `PersonOutline -> "person-outline"
  | `Person -> "person"
  | `SaveOutline -> "save-outline"
  | `Save -> "save"
  | `SchoolOutline -> "school-outline"
  | `School -> "school"
  | `TrashOutline -> "trash-outline"
  | `Trash -> "trash")
  |> fun icon_class ->
  i ~a:[ a_class [ Format.asprintf "icon-%s" icon_class ] ] []
;;

let language_select
    options
    selected
    ?(field = Pool_common.Message.Field.Language)
    ?(attributes = [])
    ()
  =
  let open Pool_common in
  let name = Message.Field.show field in
  div
    ~a:[ a_class [ "select" ] ]
    [ select
        ~a:([ a_name name ] @ attributes)
        (CCList.map
           (fun l ->
             let is_selected =
               selected
               |> CCOption.map (fun selected ->
                      if Language.equal selected l
                      then [ a_selected () ]
                      else [])
               |> CCOption.value ~default:[]
             in
             option
               ~a:([ a_value (Language.code l) ] @ is_selected)
               (txt (Language.code l)))
           options)
    ]
;;

let csrf_attibs ?id csrf =
  let attribs = [ a_input_type `Hidden; a_name "_csrf"; a_value csrf ] in
  match id with
  | Some id -> a_id id :: attribs
  | None -> attribs
;;

let csrf_element csrf ?id = input ~a:(csrf_attibs ?id csrf)

(* TODO [aerben] add way to provide additional attributes (min for numbers,
   required) *)
(* TODO [aerben] make this value arg optional *)

let input_element
    ?(orientation = `Vertical)
    ?(classnames = [])
    ?label_field
    ?help
    ?info
    language
    input_type
    name
    value
  =
  let input_label =
    CCOption.value ~default:name label_field
    |> Pool_common.Utils.field_to_string language
    |> CCString.capitalize_ascii
    |> fun n ->
    match info with
    | Some info -> Format.asprintf "%s (%s)" n info
    | None -> Format.asprintf "%s" n
  in
  let additional_classes =
    match input_type with
    | `Datetime -> [ "datepicker" ]
    | `Time -> [ "spanpicker" ]
    | _ -> []
  in
  let base_attributes =
    [ a_input_type input_type; a_value value; a_class additional_classes ]
  in
  let attributes =
    base_attributes @ [ a_name (name |> Pool_common.Message.Field.show) ]
  in
  match input_type with
  | `Hidden -> input ~a:attributes ()
  | _ ->
    let group_class =
      [ "form-group" ]
      @ classnames
      @
      match orientation with
      | `Vertical -> []
      | `Horizontal -> [ "horizontal"; "flex-gap" ]
    in
    let help =
      match help with
      | None -> []
      | Some help ->
        [ span
            ~a:[ a_class [ "help" ] ]
            [ txt Pool_common.(Utils.text_to_string language help) ]
        ]
    in
    let input_element =
      match orientation with
      | `Vertical -> input ~a:attributes ()
      | `Horizontal ->
        div ~a:[ a_class [ "input-group" ] ] [ input ~a:attributes () ]
    in
    div
      ~a:[ a_class group_class ]
      ([ label [ txt input_label ]; input_element ] @ help)
;;

(* Use the value from flash as the value, if no value is in flash use a default
   value *)
let input_element_persistent ?info ?value language input_type name flash_fetcher
  =
  let old_value = name |> Pool_common.Message.Field.show |> flash_fetcher in
  let value =
    CCOption.or_ old_value ~else_:value |> CCOption.get_or ~default:""
  in
  input_element ?info language input_type name value
;;

let textarea_element
    language
    name
    value
    ?(classnames = [])
    ?(attributes = [])
    ()
  =
  let input_label = Pool_common.Utils.field_to_string language name in
  let input =
    textarea
      ~a:
        ([ a_name (name |> Pool_common.Message.Field.show); a_class classnames ]
        @ attributes)
      (txt value)
  in
  div ~a:[ a_class [ "form-group" ] ] [ label [ txt input_label ]; input ]
;;

let textarea_element_persisted
    language
    name
    ?value
    ?(classnames = [])
    ?(attributes = [])
    flash_fetcher
  =
  let old_value = name |> Pool_common.Message.Field.show |> flash_fetcher in
  let value =
    CCOption.or_ old_value ~else_:value |> CCOption.get_or ~default:""
  in
  textarea_element language name value ~classnames ~attributes ()
;;

let submit_element
    lang
    control
    ?(submit_type = `Primary)
    ?(classnames = [])
    ?has_icon
    ()
  =
  let button_type_class =
    (match has_icon with
    | Some _ -> [ "has-icon" ]
    | None -> [])
    @ CCList.pure
    @@
    match submit_type with
    | `Disabled -> "disabled"
    | `Error -> "error"
    | `Primary -> "primary"
    | `Success -> "success"
  in
  let text_content =
    span [ txt Pool_common.Utils.(control_to_string lang control) ]
  in
  let content =
    CCOption.map_or
      ~default:[ text_content ]
      (fun i -> [ icon i; text_content ])
      has_icon
  in
  button
    ~a:[ a_button_type `Submit; a_class (classnames @ button_type_class) ]
    content
;;

let submit_icon ?(classnames = []) icon_type =
  button
    ~a:[ a_button_type `Submit; a_class (classnames @ [ "has-icon" ]) ]
    [ icon icon_type ]
;;
