open Entity_i18n

let to_string = function
  | DashboardTitle -> "Dashboard"
  | EmailConfirmationNote ->
    "Bitte prüfen Sie zunächst Ihre E-Mails und bestätigen Sie Ihre Adresse."
  | EmailConfirmationTitle -> "Bestätigung Ihrer Email Adresse"
  | ExperimentListTitle -> "Experimente"
  | ExperimentNewTitle -> "Neues Experiment erstellen"
  | ExperimentSessionReminderHint ->
    "Dies sind Standardeinstellungen für die Sessions dieses Experiment. Diese \
     Einstellungen können pro Session angepasst werden."
  | ExperimentWaitingListTitle -> "Warteliste"
  | ExperimentContactEnrolledNote ->
    "Sie sind an der folgenden Session angemeldet:"
  | HomeTitle -> "Willkommen beim Pool Tool"
  | I18nTitle -> "Übersetzungen"
  | InvitationListTitle -> "Einladungen"
  | InvitationNewTitle -> "Einladung senden"
  | NoEntries field ->
    Format.asprintf
      "Es existiert noch keine %s."
      (Locales_de.field_to_string field)
  | LoginTitle -> "Anmelden"
  | NumberIsDaysHint -> "Tage"
  | NumberIsWeeksHint -> "Wochen"
  | ResetPasswordLink | ResetPasswordTitle -> "Passwort zurücksetzen"
  | SessionListTitle -> "Sessions"
  | SessionNewTitle -> "Neue Session"
  | SessionUpdateTitle -> "Session updaten"
  | SessionSignUpTitle -> "Für diese Session anmelden"
  | SignUpAcceptTermsAndConditions -> "Ich akzeptiere die Nutzungsbedingungen."
  | SignUpTitle -> "Registrieren"
  | TermsAndConditionsTitle -> "Nutzungsbedingungen"
  | UserProfileDetailsSubtitle -> "Persönliche Angaben"
  | UserProfileLoginSubtitle -> "Anmeldeinformationen"
  | UserProfilePausedNote ->
    "Sie haben alle Benachrichtigungen für Ihren Benutzer pausiert! (Klicken \
     Sie auf 'Bearbeiten', um diese Einstellung)"
  | UserProfileTitle -> "Benutzerprofil"
;;

let nav_link_to_string = function
  | Dashboard -> "Dashboard"
  | Experiments -> "Experimente"
  | I18n -> "Übersetzungen"
  | Invitations -> "Einladungen"
  | Profile -> "Profil"
  | Sessions -> "Sessions"
  | Settings -> "Einstellungen"
  | Tenants -> "Tenants"
  | WaitingList -> "Warteliste"
;;
