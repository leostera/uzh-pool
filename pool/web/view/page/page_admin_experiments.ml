open Tyxml.Html
open Component
module Message = Pool_common.Message

(* TODO [timhub]: create global nav component, when MR is merged *)
let subnav language id =
  let open Pool_common in
  I18n.
    [ Invitations, "/invitations"
    ; WaitingList, "/waiting-list"
    ; Sessions, "/sessions"
    ]
  |> CCList.map (fun (label, url) ->
         a
           ~a:
             [ a_href
                 (Sihl.Web.externalize_path
                    (Format.asprintf
                       "/admin/experiments/%s/%s"
                       (Id.value id)
                       url))
             ]
           [ txt (Utils.nav_link_to_string language label) ])
  |> nav ~a:[ a_class [ "sub-nav" ] ]
;;

let index experiment_list Pool_context.{ language; _ } =
  let experiment_item (experiment : Experiment.t) =
    let open Experiment in
    div
      ~a:[ a_class [ "flexrow"; "space-between"; "inset-sm" ] ]
      [ span [ txt (Title.value experiment.title) ]
      ; a
          ~a:
            [ a_href
                (Sihl.Web.externalize_path
                   (Format.asprintf
                      "/admin/experiments/%s"
                      (experiment.id |> Pool_common.Id.value)))
            ]
          [ txt Pool_common.(Message.More |> Utils.control_to_string language) ]
      ]
  in
  div
    ~a:[ a_class [ "trim"; "safety-margin"; "measure" ] ]
    [ h1
        ~a:[ a_class [ "heading-1" ] ]
        [ txt
            Pool_common.(Utils.text_to_string language I18n.ExperimentListTitle)
        ]
    ; div
        ~a:[ a_class [ "stack" ] ]
        [ div
            ~a:[ a_class [ "striped" ] ]
            (CCList.map experiment_item experiment_list)
        ; p
            [ a
                ~a:
                  [ a_href (Sihl.Web.externalize_path "/admin/experiments/new")
                  ]
                [ txt
                    Pool_common.(
                      Message.(Add (Some Field.Experiment))
                      |> Utils.control_to_string language)
                ]
            ]
        ]
    ]
;;

let form ?experiment Pool_context.{ language; csrf; _ } =
  let open Experiment in
  let action =
    match experiment with
    | None -> "/admin/experiments"
    | Some experiment ->
      Format.asprintf
        "/admin/experiments/%s"
        (experiment.id |> Pool_common.Id.value)
  in
  let value = CCFun.flip (CCOption.map_or ~default:"") experiment in
  div
    ~a:[ a_class [ "trim"; "safety-margin"; "narrow"; "stack" ] ]
    [ h1
        [ txt
            Pool_common.(
              Utils.text_to_string Language.En I18n.ExperimentNewTitle)
        ]
    ; form
        ~a:
          [ a_method `Post
          ; a_action (Sihl.Web.externalize_path action)
          ; a_class [ "stack" ]
          ]
        [ Component.csrf_element csrf ()
        ; input_element
            language
            `Text
            Pool_common.Message.Field.Title
            (value title_value)
        ; input_element
            language
            `Text
            Pool_common.Message.Field.Description
            (value description_value)
        ; h3 ~a:[ a_class [ "heading-3" ] ] [ txt "Session reminder" ]
        ; p
            [ txt
                Pool_common.(
                  Utils.text_to_string
                    language
                    I18n.ExperimentSessionReminderHint)
            ]
        ; input_element
            language
            `Number
            Pool_common.Message.Field.LeadTime
            (value (fun experiment ->
                 experiment
                 |> session_reminder_lead_time_value
                 |> Ptime.Span.to_int_s
                 |> CCOption.map CCInt.to_string
                 |> CCOption.value ~default:""))
        ; textarea_element
            language
            Pool_common.Message.Field.ReminderText
            (value (fun experiment ->
                 experiment
                 |> session_reminder_text_value
                 |> CCOption.value ~default:""))
            ()
        ; submit_element
            language
            Message.(
              let field = Some Field.Experiment in
              match experiment with
              | None -> Create field
              | Some _ -> Update field)
            ~submit_type:`Success
            ()
        ]
    ]
;;

let detail experiment session_count Pool_context.{ language; _ } =
  let delete_form =
    match session_count > 0 with
    | true ->
      div
        [ submit_element
            language
            Message.(Delete (Some Field.Experiment))
            ~submit_type:`Disabled
            ()
        ; p
            [ small
                [ txt
                    Pool_common.(
                      Message.ExperimentSessionCountNotZero
                      |> Utils.error_to_string language)
                ]
            ]
        ]
    | false ->
      Tyxml.Html.form
        ~a:
          [ a_method `Post
          ; a_action
              (Sihl.Web.externalize_path
                 (Format.asprintf
                    "/admin/experiments/%s/delete"
                    (experiment.Experiment.id |> Pool_common.Id.value)))
          ]
        [ submit_element
            language
            Message.(Delete (Some Field.Experiment))
            ~submit_type:`Error
            ~has_icon:`TrashOutline
            ()
        ]
  in
  let field_to_string = Pool_common.Utils.field_to_string language in
  let open Experiment in
  div
    ~a:[ a_class [ "safety-margin"; "trim"; "measure" ] ]
    [ subnav language experiment.id
    ; h1
        ~a:[ a_class [ "heading-1" ] ]
        [ txt (experiment.title |> Title.value) ]
    ; p [ txt (experiment.description |> Description.value) ]
    ; table
        ~a:[ a_class [ "striped" ] ]
        [ tr
            [ th
                [ txt (field_to_string Pool_common.Message.Field.ReminderText) ]
            ; td
                [ txt
                    (session_reminder_text_value experiment
                    |> CCOption.value ~default:"")
                ]
            ]
        ; tr
            [ th [ txt (field_to_string Pool_common.Message.Field.LeadTime) ]
              (* TODO: Format time values *)
            ; td
                [ txt
                    (session_reminder_lead_time_value experiment
                    |> Ptime.Span.to_float_s
                    |> CCFloat.to_string)
                ]
            ]
        ]
    ; p
        [ a
            ~a:
              [ a_href
                  (Sihl.Web.externalize_path
                     (Format.asprintf
                        "/admin/experiments/%s/edit"
                        (experiment.id |> Pool_common.Id.value)))
              ]
            [ txt
                Pool_common.(
                  Message.(Edit (Some Field.Experiment))
                  |> Utils.control_to_string language)
            ]
        ]
    ; delete_form
    ]
;;

let invitations
    invitations
    experiment
    filtered_contacts
    (Pool_context.{ language; _ } as context)
  =
  div
    ~a:[ a_class [ "trim"; "safety-margin" ] ]
    [ subnav language experiment.Experiment.id
    ; h1
        ~a:[ a_class [ "heading-1" ] ]
        [ txt
            Pool_common.(Utils.text_to_string language I18n.InvitationListTitle)
        ]
    ; div
        ~a:[ a_class [ "stack-lg" ] ]
        [ Page_admin_invitations.Partials.list context experiment invitations
        ; Page_admin_invitations.Partials.send_invitation
            context
            experiment
            filtered_contacts
        ]
    ]
;;

let waiting_list waiting_list Pool_context.{ language; _ } =
  let open Waiting_list.ExperimentList in
  let waiting_list_entries =
    CCList.map
      (fun entry ->
        tr
          [ td [ txt (Contact.Preview.fullname entry.contact) ]
          ; td
              [ txt
                  (Contact.Preview.email_address entry.contact
                  |> Pool_user.EmailAddress.value)
              ]
          ; td
              [ a
                  ~a:
                    [ a_href
                        (Sihl.Web.externalize_path
                           (Format.asprintf
                              "/admin/experiments/waiting-list/%s"
                              (entry.id |> Pool_common.Id.value)))
                    ]
                  [ txt
                      Pool_common.(
                        Message.More |> Utils.control_to_string language)
                  ]
              ]
          ])
      waiting_list.waiting_list_entries
    |> table ~a:[ a_class [ "striped" ] ]
  in
  div
    ~a:[ a_class [ "trim"; "safety-margin" ] ]
    [ subnav language waiting_list.experiment.Experiment.id
    ; h1
        ~a:[ a_class [ "heading-1" ] ]
        [ txt
            Pool_common.(
              Utils.text_to_string language I18n.ExperimentWaitingListTitle)
        ]
    ; waiting_list_entries
    ]
;;
