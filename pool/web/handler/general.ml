let user_from_session db_pool req : Sihl_user.t option Lwt.t =
  let ctx = Tenant_pool.pool_to_ctx db_pool in
  Service.User.Web.user_from_session ~ctx req
;;
