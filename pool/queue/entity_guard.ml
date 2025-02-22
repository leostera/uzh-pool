module Access = struct
  open Guard
  open ValidationSet
  open Permission

  let index = one_of_tuple (Read, `Queue, None)
  let read = one_of_tuple (Read, `Queue, None)
end
