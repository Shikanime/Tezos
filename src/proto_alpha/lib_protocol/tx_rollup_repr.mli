(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2021 Marigold <contact@marigold.dev>                        *)
(* Copyright (c) 2021 Nomadic Labs <contact@nomadic-labs.com>                *)
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

(** This module defines identifiers for transactional only rollup (or tx rollup)
    . It also specifies how to compute originated contract's hash from
    origination nonce. *)

(** A specialized Blake2B implementation for hashing rollup identifiers. *)
module Hash : sig
  val rollup_hash : string

  include S.HASH
end

type t = private Hash.t

type tx_rollup = t

include Compare.S with type t := t

val to_b58check : t -> string

val of_b58check : string -> t tzresult

val pp : Format.formatter -> t -> unit

val encoding : t Data_encoding.t

type creation_nonce

val created_tx_rollup : creation_nonce -> t

val initial_creation_nonce : Operation_hash.t -> creation_nonce

val incr_creation_nonce : creation_nonce -> creation_nonce

val rpc_arg : t RPC_arg.arg

module Index : Storage_description.INDEX with type t = t

type pending_inbox

val pending_inbox_encoding : pending_inbox Data_encoding.t

val empty_pending_inbox : pending_inbox
