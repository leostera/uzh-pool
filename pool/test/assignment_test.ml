module ContactCommand = Cqrs_command.Contact_command
module AssignmentCommand = Cqrs_command.Assignment_command
module Field = Pool_common.Message.Field

let check_result expected generated =
  Alcotest.(
    check
      (result (list Test_utils.event) Test_utils.error)
      "succeeds"
      expected
      generated)
;;

type assignment_data =
  { session : Session.Public.t
  ; experiment : Experiment.t
  ; contact : Contact.t
  }

let assignment_data () =
  let session = Test_utils.create_public_session () in
  let experiment = Test_utils.create_experiment () in
  let contact = Test_utils.create_contact () in
  { session; experiment; contact }
;;

let confirmation_email =
  let language = Pool_common.Language.En in
  let subject = "Confirmation" |> I18n.Content.create |> CCResult.get_exn in
  let text = "Text" |> I18n.Content.create |> CCResult.get_exn in
  let session_text = "Session info" in
  Assignment.{ subject; text; language; session_text }
;;

let create () =
  let { session; experiment; contact } = assignment_data () in
  let waiting_list =
    Test_utils.create_waiting_list_from_experiment_and_contact
      experiment
      contact
  in
  let events =
    let command =
      AssignmentCommand.Create.
        { contact; session; waiting_list = Some waiting_list }
    in
    AssignmentCommand.Create.handle command confirmation_email false
  in
  let expected =
    Ok
      [ Waiting_list.Deleted waiting_list |> Pool_event.waiting_list
      ; Assignment.(Created { contact; session_id = session.Session.Public.id })
        |> Pool_event.assignment
      ; Assignment.(
          ConfirmationSent
            (confirmation_email, waiting_list.Waiting_list.contact))
        |> Pool_event.assignment
      ]
  in
  check_result expected events
;;

let canceled () =
  let assignment = Test_utils.create_assignment () in
  let events = AssignmentCommand.Cancel.handle assignment in
  let expected =
    Ok [ Assignment.Canceled assignment |> Pool_event.assignment ]
  in
  check_result expected events
;;

let set_attendance () =
  let assignment = Test_utils.create_assignment () in
  let show_up = "true" in
  let participated = "false" in
  let events =
    let attendance =
      Pool_common.Utils.get_or_failwith
      @@ AssignmentCommand.SetAttendance.decode
           [ Field.(ShowUp |> show), show_up |> CCList.pure
           ; Field.(Participated |> show), participated |> CCList.pure
           ]
    in
    AssignmentCommand.SetAttendance.handle assignment attendance
  in
  let expected =
    let open Assignment in
    Ok
      [ ShowedUp (assignment, show_up |> bool_of_string |> ShowUp.create)
        |> Pool_event.assignment
      ; Participated
          (assignment, participated |> bool_of_string |> Participated.create)
        |> Pool_event.assignment
      ]
  in
  check_result expected events
;;

let assign_to_fully_booked_session () =
  let { session; experiment; contact } = assignment_data () in
  let session = session |> Test_utils.fully_book_public_session in
  let waiting_list =
    Test_utils.create_waiting_list_from_experiment_and_contact
      experiment
      contact
  in
  let events =
    let command =
      AssignmentCommand.Create.
        { contact; session; waiting_list = Some waiting_list }
    in
    AssignmentCommand.Create.handle command confirmation_email false
  in
  let expected = Error Pool_common.Message.(SessionFullyBooked) in
  check_result expected events
;;

let assign_to_session_contact_is_already_assigned () =
  let { session; experiment; contact } = assignment_data () in
  let already_assigned = true in
  let waiting_list =
    Test_utils.create_waiting_list_from_experiment_and_contact
      experiment
      contact
  in
  let events =
    let command =
      AssignmentCommand.Create.
        { contact; session; waiting_list = Some waiting_list }
    in
    AssignmentCommand.Create.handle command confirmation_email already_assigned
  in
  let expected = Error Pool_common.Message.(AlreadySignedUpForExperiment) in
  check_result expected events
;;

let assign_contact_from_waiting_list () =
  let session = Test_utils.create_session () in
  let waiting_list = Test_utils.create_waiting_list () in
  let already_enrolled = false in
  let events =
    let command =
      AssignmentCommand.CreateFromWaitingList.
        { session; waiting_list; already_enrolled }
    in
    AssignmentCommand.CreateFromWaitingList.handle command confirmation_email
  in
  let expected =
    let create =
      Assignment.
        { contact = waiting_list.Waiting_list.contact
        ; session_id = session.Session.id
        }
    in
    Ok
      [ Waiting_list.Deleted waiting_list |> Pool_event.waiting_list
      ; Assignment.Created create |> Pool_event.assignment
      ; Assignment.(
          ConfirmationSent
            (confirmation_email, waiting_list.Waiting_list.contact))
        |> Pool_event.assignment
      ]
  in
  check_result expected events
;;

let assign_contact_from_waiting_list_to_disabled_experiment () =
  let session = Test_utils.create_session () in
  let experiment = Test_utils.create_experiment () in
  let experiment =
    Experiment.
      { experiment with
        registration_disabled = true |> RegistrationDisabled.create
      }
  in
  let waiting_list = Test_utils.create_waiting_list () in
  let waiting_list = Waiting_list.{ waiting_list with experiment } in
  let already_enrolled = false in
  let events =
    let command =
      AssignmentCommand.CreateFromWaitingList.
        { session; waiting_list; already_enrolled }
    in
    AssignmentCommand.CreateFromWaitingList.handle command confirmation_email
  in
  let expected = Error Pool_common.Message.(RegistrationDisabled) in
  check_result expected events
;;