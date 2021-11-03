open Client_baking_forge
module I = Internal_for_tests
module A = Protocol.Alpha_context

(* [contains ~equal l1 l2 tests] return true if all elements of [l2] are in [l1] *)
let contains ~equal l1 l2 =
  let rec loop = function
    | [] -> true
    | hd :: tl -> List.mem ~equal hd l1 && loop tl
  in
  loop l2

(* A single dummy container for a manager operation *)
let dumy_manager_operation_template =
  {|{"branch": "BKn5FnsyMQsJnWX1pRFgqRCMVLE91Hu4F248w6L6Ncd6GCGGuMy",
   "contents": [{"kind": "transaction", "source": "%s",
   "tz1gjaF81ZRRvdzjobyfVNsAeSC6PScjfQwN", "fee": "402", "counter": "%d",
   "gas_limit": "1520", "storage_limit": "0", "amount": "2000000", "destination":
   "tz1faswCTDciRzE4oJ9jn2Vm2dvjeyA9fUzU"}], "signature":
   "sigiJ67JFMb9yPKJE7Bk64o77BBT9e8vkf3zowixtyFZVhwDJuEh75YYerZf8mFUywvGEWePzqC4W6gDzCptvTa58Ha86pBo"}|}

(* Constructing manager operations. We only care about changing source and
 * counter to test the sorting routine, *)
let manager_operation ?(source = "tz1gjaF81ZRRvdzjobyfVNsAeSC6PScjfQwN")
    ~(counter : int) () =
  let fmt = Scanf.format_from_string dumy_manager_operation_template "%s %d" in
  Format.asprintf fmt source counter

(* Default contents for operation sources *)
let external_mempool_operations =
  [manager_operation ~counter:2 (); manager_operation ~counter:3 ()]

let node_mempool_operations = [manager_operation ~counter:3 ()]

let empty_operations = []

let read_json_op_from_string s =
  match Data_encoding.Json.from_string s with
  | Ok json -> Data_encoding.Json.destruct A.Operation.encoding json
  | Error _ -> assert false

let prioritized_operations =
  List.map
    (fun op -> I.PrioritizedOperation.extern (read_json_op_from_string op))
    external_mempool_operations
  @ List.map
      (fun op -> I.PrioritizedOperation.node (read_json_op_from_string op))
      node_mempool_operations

(* Verify that we do not introduce operations for the empty list*)
let test_empty () =
  let sorted_operations =
    I.sort_manager_operations
      ~max_size:max_int
      ~hard_gas_limit_per_block:Protocol.Saturation_repr.zero
      ~minimal_fees:A.Tez.zero
      ~minimal_nanotez_per_byte:Q.zero
      ~minimal_nanotez_per_gas_unit:Q.zero
      empty_operations
  in
  if not @@ contains ~equal:( == ) empty_operations sorted_operations then
    failwith "oops"
  else return_unit

(* Check that any 2 consecutive elements in list l obey the following sorting
 * rule.

   If a happens before b in l then:
   - a's priority is higher than b's; or
   - if a and b have the same source, then a's counter is smaller than b's; or
   - if they do not have the same source, we assume it's ok. The ordering
   actually depends on a computed weight but we do not check that here.
 *)
let rec check_2_by_2 l =
  let open I in
  let open PrioritizedOperation in
  match l with
  | [] | [_] -> true
  | x :: (y :: _ as l) -> (
      if x.priority > y.priority then check_2_by_2 l
      else
        x.priority = y.priority
        &&
        match (I.get_manager_content x, I.get_manager_content y) with
        | (Some (xsrc, xcounter), Some (ysrc, ycounter)) ->
            if Signature.Public_key_hash.equal xsrc ysrc then
              (* lower counter come first *)
              Z.compare xcounter ycounter < 0 && check_2_by_2 l
            else check_2_by_2 l
        (* there is another weight criterion used for ordering but
           we do not test it *)
        | (None, _) | (_, None) -> false)

let test_sorting () =
  let sorted_operations =
    I.sort_manager_operations
      ~max_size:max_int
      ~hard_gas_limit_per_block:Protocol.Saturation_repr.one
      ~minimal_fees:A.Tez.zero
      ~minimal_nanotez_per_byte:Q.zero
      ~minimal_nanotez_per_gas_unit:Q.zero
      prioritized_operations
  in
  (* All elements in the results exist in the original*)
  if not @@ contains ~equal:( == ) prioritized_operations sorted_operations then
    failwith "oops"
  else if check_2_by_2 sorted_operations then return_unit
  else failwith "oops resorted"

let tests =
  [
    Tztest.tztest "empty is empty" `Quick test_empty;
    Tztest.tztest "sorting ok" `Quick test_sorting;
  ]
