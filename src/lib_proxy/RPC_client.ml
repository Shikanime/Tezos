(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2020 Nomadic Labs, <contact@nomadic-labs.com>               *)
(*                                                                           *)
(* Permission is hereby granted, free of charge, to any person obtaining a   *)
(* copy of this software and associated documentation files (the "Software"),*)
(* to deal in the Software without restriction, including without limitation *)
(* the rights to use, copy, modify, merge, publish, distribute, sublicense,  *)
(* and/or sell copies of the Software, and to permit persons to whom the     *)
(* Software is furnished to do so, subject to the following conditions:      *)
(*                                                                           *)
(* The above copyright notice and this permission notice shall be included   *)
(* in all copies or substantial portions of the Software.                    *)
(*                                                                           *)
(* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR*)
(* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  *)
(* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL   *)
(* THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER*)
(* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING   *)
(* FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER       *)
(* DEALINGS IN THE SOFTWARE.                                                 *)
(*                                                                           *)
(*****************************************************************************)

module Service = RPC_service

module L = Internal_event.Legacy_logging.Make (struct
  let name = "proxy_rpc_ctxt"
end)

let rec print_path : type pr p. (pr, p) Resto.Internal.path -> string list =
 fun path ->
  match path with
  | Root ->
      []
  | Static (path, s) ->
      s :: print_path path
  | Dynamic (path, arg) ->
      Printf.sprintf "<%s>" arg.descr.name :: print_path path
  | DynamicTail (path, arg) ->
      Printf.sprintf "<%s>" arg.descr.name :: print_path path

(* TODO Once https://gitlab.com/nomadic-labs/resto/-/issues/3 is
   fixed, use the corresponding function from resto. The same applies
   to print_path above.

   And at the same time, do the same in the mockup mode; which
   has these functions too. *)
let print_service : type p q i o. (_, _, p, q, i, o) Service.t -> string =
 fun serv ->
  let iserv = Service.Internal.to_service serv in
  String.concat "/" (List.rev (print_path iserv.path))

let method_is_writer = function
  | `POST | `DELETE | `PUT | `PATCH ->
      true
  | `GET ->
      false

class http_local_ctxt (printer : Tezos_client_base.Client_context.printer)
  (http_ctxt : RPC_context.json) (proxy_env : Registration.proxy_environment) :
  RPC_context.json =
  let local_ctxt =
    Tezos_mockup_proxy.RPC_client.local_ctxt
      (Proxy_services.build_directory printer http_ctxt proxy_env)
  in
  let dispatch_local_or_distant ~debug_name ~local ~distant meth path =
    let meth_string = RPC_service.string_of_meth meth in
    let delegate () =
      L.debug "Delegating %s %s %s to http" meth_string debug_name path ;
      distant ()
    in
    if method_is_writer meth then delegate ()
    else
      local ()
      >>= function
      | Ok x ->
          L.debug "Done %s %s %s locally" meth_string debug_name path ;
          return x
      | Error [Tezos_rpc.RPC_context.Not_found _] ->
          delegate ()
      | Error _ as err ->
          Lwt.return err
  in
  object
    method base = Uri.empty

    method call_service
        : 'm 'p 'q 'i 'o.
          (([< Resto.meth] as 'm), unit, 'p, 'q, 'i, 'o) RPC_service.t -> 'p ->
          'q -> 'i -> 'o tzresult Lwt.t =
      fun service params query input ->
        let local () = local_ctxt#call_service service params query input in
        let distant () = http_ctxt#call_service service params query input in
        let meth = RPC_service.meth service in
        dispatch_local_or_distant
          ~debug_name:"call_service"
          ~local
          ~distant
          meth
        @@ print_service service

    method call_streamed_service
        : 'm 'p 'q 'i 'o.
          (([< Resto.meth] as 'm), 'pr, 'p, 'q, 'i, 'o) RPC_service.t ->
          on_chunk:('o -> unit) -> on_close:(unit -> unit) -> 'p -> 'q -> 'i ->
          (unit -> unit) tzresult Lwt.t =
      fun service ~on_chunk ~on_close params query input ->
        let local () =
          local_ctxt#call_streamed_service
            service
            ~on_chunk
            ~on_close
            params
            query
            input
        in
        let distant () =
          http_ctxt#call_streamed_service
            service
            ~on_chunk
            ~on_close
            params
            query
            input
        in
        let meth = RPC_service.meth service in
        dispatch_local_or_distant
          ~debug_name:"call_streamed_service"
          ~local
          ~distant
          meth
        @@ print_service service

    method generic_json_call
        : RPC_service.meth ->
          ?body:Data_encoding.json ->
          Uri.t ->
          ( Data_encoding.json,
            Data_encoding.json option )
          RPC_context.rest_result
          Lwt.t =
      fun meth ?body uri ->
        let meth_string = RPC_service.string_of_meth meth in
        let uri_string = Uri.to_string uri in
        let delegate () =
          L.debug
            "Delegating generic_json_call %s %s to http"
            meth_string
            uri_string ;
          http_ctxt#generic_json_call meth ?body uri
        in
        if method_is_writer meth then delegate ()
        else
          local_ctxt#generic_json_call meth ?body uri
          >>= fun y ->
          match y with
          | Ok (`Not_found _) | Error [Tezos_rpc.RPC_context.Not_found _] ->
              delegate ()
          | Ok x ->
              L.debug
                "Done generic_json_call %s %s locally"
                meth_string
                uri_string ;
              return x
          | Error _ as err ->
              Lwt.return err
  end
