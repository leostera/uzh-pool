include Entity
include Event

let find_all_for_experiment = Repo.find_all_for_experiment
let find_all_public_for_experiment = Repo.find_all_public_for_experiment
let find = Repo.find
let find_public = Repo.find_public

module Repo = struct
  module Public = struct
    let t = Repo_entity.Public.t
  end
end
