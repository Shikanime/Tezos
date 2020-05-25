(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2018 Dynamic Ledger Solutions, Inc. <contact@tezos.com>     *)
(* Copyright (c) 2020 Metastate AG <hello@metastate.dev>                     *)
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

(** Each baker has a [frozen_balance] for each cycle in which it's active. When
    a baker is convicted of double baking or double endorsement in a given cycle,
    a half of the frozen deposits and fees goes to a baker who included the
    evidence in the block and the rest (including any rewards) gets burnt. *)
type frozen_balance = {
  deposit : Tez_repr.t;
  fees : Tez_repr.t;
  rewards : Tez_repr.t;
}

type error +=
  | Balance_too_low_for_deposit of {
      delegate : Signature.Public_key_hash.t;
      deposit : Tez_repr.t;
      balance : Tez_repr.t;
    }

(** Iterate on all registered delegates. *)
val fold :
  Raw_context.t ->
  init:'a ->
  f:(Signature.Public_key_hash.t -> 'a -> 'a Lwt.t) ->
  'a Lwt.t

(** List all registered delegates. *)
val list : Raw_context.t -> Signature.Public_key_hash.t list Lwt.t

(** Various functions to 'freeze' tokens.  A frozen 'deposit' keeps its
    associated rolls. When frozen, 'fees' may trigger new rolls
    allocation. Rewards won't trigger new rolls allocation until
    unfrozen. *)
val freeze_deposit :
  Raw_context.t ->
  Signature.Public_key_hash.t ->
  Tez_repr.t ->
  Raw_context.t tzresult Lwt.t

val freeze_fees :
  Raw_context.t ->
  Signature.Public_key_hash.t ->
  Tez_repr.t ->
  Raw_context.t tzresult Lwt.t

val freeze_rewards :
  Raw_context.t ->
  Signature.Public_key_hash.t ->
  Tez_repr.t ->
  Raw_context.t tzresult Lwt.t

(** Trigger the context maintenance at the end of cycle 'n', i.e.:
    unfreeze deposit/fees/rewards from 'n - preserved_cycle' ; punish the
    provided unrevealed seeds (tipically seed from cycle 'n - 1').
    Returns a list of account with the amount that was unfrozen for each
    and the list of deactivated delegates. *)
val cycle_end :
  Raw_context.t ->
  Cycle_repr.t ->
  Nonce_storage.unrevealed list ->
  ( Raw_context.t
  * Receipt_repr.balance_updates
  * Signature.Public_key_hash.t list )
  tzresult
  Lwt.t

(** Burn all then frozen deposit/fees/rewards for a delegate at a given
    cycle. Returns the burned amounts. *)
val punish :
  Raw_context.t ->
  Signature.Public_key_hash.t ->
  Cycle_repr.t ->
  (Raw_context.t * frozen_balance) tzresult Lwt.t

(** Has the given key some frozen tokens in its implicit contract? *)
val has_frozen_balance :
  Raw_context.t ->
  Signature.Public_key_hash.t ->
  Cycle_repr.t ->
  bool tzresult Lwt.t

(** Returns the amount of frozen deposit, fees and rewards associated
    to a given delegate. *)
val frozen_balance :
  Raw_context.t -> Signature.Public_key_hash.t -> Tez_repr.t tzresult Lwt.t

val frozen_balance_encoding : frozen_balance Data_encoding.t

val frozen_balance_by_cycle_encoding :
  frozen_balance Cycle_repr.Map.t Data_encoding.t

(** Returns the amount of frozen deposit, fees and rewards associated
    to a given delegate, indexed by the cycle by which at the end the
    balance will be unfrozen. *)
val frozen_balance_by_cycle :
  Raw_context.t ->
  Signature.Public_key_hash.t ->
  frozen_balance Cycle_repr.Map.t Lwt.t

(** Returns the full 'balance' of the implicit contract associated to
    a given key, i.e. the sum of the spendable balance and of the
    frozen balance. *)
val full_balance :
  Raw_context.t -> Signature.Public_key_hash.t -> Tez_repr.t tzresult Lwt.t

val staking_balance :
  Raw_context.t -> Signature.Public_key_hash.t -> Tez_repr.t tzresult Lwt.t

(** Returns the list of contracts (implicit or originated) that delegated towards a given delegate *)
val delegated_contracts :
  Raw_context.t -> Signature.Public_key_hash.t -> Contract_repr.t list Lwt.t

val delegated_balance :
  Raw_context.t -> Signature.Public_key_hash.t -> Tez_repr.t tzresult Lwt.t

val deactivated :
  Raw_context.t -> Signature.Public_key_hash.t -> bool tzresult Lwt.t

val grace_period :
  Raw_context.t -> Signature.Public_key_hash.t -> Cycle_repr.t tzresult Lwt.t
