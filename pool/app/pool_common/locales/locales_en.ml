open Entity_message

let field_to_string =
  let open Field in
  function
  | Admin -> "admin"
  | AssetId -> "asset identifier"
  | ContactEmail -> "contact email address"
  | CreatedAt -> "Created at"
  | CurrentPassword -> "current password"
  | Database -> "database"
  | DatabaseLabel -> "database label"
  | DatabaseUrl -> "database url"
  | Date -> "date"
  | DateTime -> "date and time"
  | DefaultLanguage -> "default language"
  | Description -> "description"
  | Disabled -> "disabled"
  | Email -> "email address"
  | EmailAddress -> "email address"
  | EmailAddressUnverified -> "unverified email address"
  | EmailAddressVerified -> "verified email address"
  | EmailSuffix -> "email suffix"
  | Experiment -> "experiment"
  | File -> "file"
  | FileMimeType -> "mime type"
  | Filename -> "filename"
  | Filesize -> "filesize"
  | Firstname -> "firstname"
  | Host -> "host"
  | I18n -> "translation"
  | Icon -> "icon"
  | Id -> "identifier"
  | InactiveUserDisableAfter -> "disable inactive user after"
  | InactiveUserWarning -> "warn inactive user"
  | Invitation -> "Invitation"
  | Invitations -> "Invitations"
  | Key -> "key"
  | Language -> "language"
  | LanguageDe -> "German"
  | LanguageEn -> "English"
  | Lastname -> "lastname"
  | LogoType -> "logo type"
  | MaxParticipants -> "maximum participants"
  | MinParticipants -> "minimum participants"
  | NewPassword -> "new password"
  | Operator -> "operator"
  | Overbook -> "overbook"
  | Page -> "page"
  | Participant -> "participant"
  | ParticipantCount -> "number of participants"
  | Participants -> "participants"
  | Participated -> "participated"
  | PartnerLogos -> "partner logos"
  | Password -> "password"
  | PasswordConfirmation -> "password confirmation"
  | Paused -> "paused"
  | RecruitmentChannel -> "recruitment channel"
  | ResentAt -> "Resent at"
  | Role -> "role"
  | Root -> "root"
  | Setting -> "setting"
  | ShowUp -> "show up"
  | SmtpAuthMethod -> "smtp authentication method"
  | SmtpAuthServer -> "smtp authentication server"
  | SmtpPassword -> "smtp password"
  | SmtpPort -> "smtp port"
  | SmtpProtocol -> "smtp protocol"
  | SmtpReadModel -> "smtp read model"
  | SmtpUsername -> "smtp username"
  | SmtpWriteModel -> "smtp write model"
  | Styles -> "styles"
  | Subject -> "subject"
  | Subjects -> "subjects"
  | Tenant -> "tenant"
  | TenantDisabledFlag -> "disabled flag"
  | TenantId -> "tenant identifier"
  | TenantLogos -> "tenant logos"
  | TenantMaintenanceFlag -> "maintenance flag"
  | TenantPool -> "Tenant pool"
  | TermsAccepted -> "terms accepted"
  | TermsAndConditions -> "terms and conditions"
  | Time -> "time"
  | TimeSpan -> "time span"
  | Title -> "title"
  | Token -> "token"
  | Translation -> "translation"
  | Url -> "url"
  | User -> "user"
  | Version -> "version"
;;

let info_to_string : info -> string = function
  | Info string -> string
;;

let success_to_string : success -> string = function
  | Created field ->
    field_message "" (field_to_string field) "was successfully created."
  | EmailVerified -> "Email successfully verified."
  | EmailConfirmationMessage ->
    "Successfully created. An email has been sent to your email address for \
     verification."
  | FileDeleted -> "File was successfully deleted."
  | PasswordChanged -> "Password successfully changed."
  | PasswordReset -> "Password reset, you can now log in."
  | PasswordResetSuccessMessage ->
    "You will receive an email with a link to reset your password if an \
     account with the provided email is existing."
  | SentList field ->
    field_message "" (field_to_string field) "were successfully sent."
  | SettingsUpdated -> "Settings were updated successfully."
  | TenantUpdateDatabase -> "Database information was successfully updated."
  | TenantUpdateDetails -> "Tenant was successfully updated."
  | Updated field ->
    field_message "" (field_to_string field) "was successfully updated."
;;

let warning_to_string : warning -> string = function
  | Warning string -> string
;;

let rec error_to_string = function
  | Conformist errs ->
    CCList.map
      (fun (field, err) ->
        Format.asprintf
          "%s: %s"
          (field_to_string field |> CCString.capitalize_ascii)
          (error_to_string err))
      errs
    |> CCString.concat "\n"
  | ConformistModuleErrorType -> failwith "Do not use"
  | DecodeAction -> "Cannot decode action."
  | Decode field -> field_message "Cannot decode" (field_to_string field) ""
  | Disabled field -> field_message "" (field_to_string field) "is disabled."
  | EmailAddressMissingOperator -> "Please provide operator email address."
  | EmailAddressMissingRoot -> "Please provide root email address."
  | EmailAlreadyInUse -> "Email address is already in use."
  | EmailMalformed -> "Malformed email"
  | ExperimenSessionCountNotZero ->
    "Sessions exist for this experiment. It cannot be deleted."
  | HtmxVersionNotFound field ->
    Format.asprintf "No version found for field '%s'" field
  | Invalid field -> field_message "Invalid" (field_to_string field) "provided!"
  | LoginProvideDetails -> "Please provide email and password"
  | ParticipantAmountNegative ->
    "The number of participants has to be positive!"
  | MeantimeUpdate field ->
    field_message "" (field_to_string field) "was updated in the meantime!"
  | NoOptionSelected field ->
    field_message "Please select at least one" (field_to_string field) "."
  | NotANumber field -> Format.asprintf "Version '%s' is not a number." field
  | NoTenantsRegistered -> "There are no tenants registered in root database!"
  | NotFound field -> field_message "" (field_to_string field) "not found!"
  | NotFoundList (field, items) ->
    field_message
      "Following"
      (field_to_string field)
      (Format.asprintf "could not be found: %s" (CCString.concat "," items))
  | NotHandled field -> Format.asprintf "Field '%s' is not handled." field
  | NoValue -> "No value provided."
  | SubjectSignupInvalidEmail ->
    "Please provide a valid and unused email address."
  | SubjectUnconfirmed -> "Participant isn't confirmed!"
  | PasswordPolicy msg ->
    Format.asprintf "Password doesn't match the required policy! %s" msg
  | PasswordResetInvalidData -> "Invalid token or password provided"
  | PasswordResetFailMessage ->
    "You will receive an email with a link to reset your password if an \
     account with the provided email is existing."
  | RequestRequiredFields -> "Please provide necessary fields"
  | Retrieve field -> field_message "Cannot retrieve" (field_to_string field) ""
  | SessionInvalid -> "Invalid session, please login."
  | SessionTenantNotFound ->
    "Something on our side went wrong, please try again later or on multi \
     occurrences please contact the Administrator."
  | PoolContextNotFound -> "Context could not be found."
  | TerminatoryTenantError | TerminatoryRootError -> "Please try again later."
  | TerminatoryTenantErrorTitle | TerminatoryRootErrorTitle ->
    "An error occurred"
  | TermsAndConditionsMissing -> "Terms and conditions have to be added first."
  | TermsAndConditionsNotAccepted -> "Terms and conditions not accepted"
  | TimeSpanPositive -> "Time span must be positive!"
  | TokenInvalidFormat -> "Invalid Token Format!"
  | TokenAlreadyUsed -> "The token was already used."
  | Undefined field -> field_message "Undefined" (field_to_string field) ""
  | WriteOnlyModel -> "Write only model!"
;;

let format_submit submit field =
  let field_opt_message f =
    f |> CCOption.map field_to_string |> CCOption.value ~default:""
  in
  field_message "" submit (field_opt_message field)
;;

let control_to_string = function
  | Accept field -> format_submit "accept" field
  | Add field -> format_submit "add" field
  | Back -> format_submit "back" None
  | Choose field -> format_submit "choose" field
  | Create field -> format_submit "create" field
  | Decline -> format_submit "decline" None
  | Delete field -> format_submit "delete" field
  | Disable -> format_submit "disable" None
  | Edit field -> format_submit "edit" field
  | Enable -> format_submit "enable" None
  | Login -> format_submit "login" None
  | More -> "more"
  | Resend field -> format_submit "resend" field
  | Save field -> format_submit "save" field
  | Send field -> format_submit "send" field
  | SendResetLink -> format_submit "send reset link" None
  | SignUp -> format_submit "sign up" None
  | Update field -> format_submit "update" field
;;

let to_string = function
  | Message string -> string
  | PageNotFoundMessage -> "The requested page could not be found."
;;
