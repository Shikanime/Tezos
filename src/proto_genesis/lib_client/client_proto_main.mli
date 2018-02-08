(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2014 - 2018.                                          *)
(*    Dynamic Ledger Solutions, Inc. <contact@tezos.com>                  *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

open Proto_genesis

val bake:
  #Client_context.full_context ->
  ?timestamp: Time.t ->
  Block_services.block ->
  Data.Command.t ->
  Client_keys.sk_locator ->
  Block_hash.t tzresult Lwt.t

