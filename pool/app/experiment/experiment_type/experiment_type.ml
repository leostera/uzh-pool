include Entity

let find_public = Repo.find_public
let find_all_public_by_contact = Repo.find_all_public_by_contact

let find_public_sessions pool id contact =
  let open Lwt_result.Syntax in
  let* experiment = Repo.find_public pool id contact in
  let%lwt sessions = Session.find_all_public_for_experiment pool contact id in
  Entity.create_public_sessions experiment sessions |> Lwt_result.return
;;

let find_invitations pool id =
  let open Lwt_result.Syntax in
  let* experiment = Experiment.find pool id in
  let* invitations =
    Invitation.find_by_experiment pool experiment.Experiment.id
  in
  Lwt.return_ok { experiment; invitations }
;;
