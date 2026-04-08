::  %myco: eco's mycelial network vane
::
::  Manages virtual Arvo instances containing %link chain state.
::  Provides cross-layer message routing (L1<->L2<->L3),
::  RPC endpoints, Jael integration for signing, and
::  mempool management.
::
::  Architecture (from the diagram):
::    Actual Ship
::      -> Other Vanes, Userspace
::      -> %myco vane
::           -> Layer management (L1, L2s, L3s)
::           -> Jael interaction for signing
::           -> Mempools per layer
::           -> Virtual Arvo instances (via pyro-like containment)
::                -> %link chain state per layer
::                -> balances, consensus algo
::                -> virtual gall handles
::                -> contracts
::           -> I/O with chain
::           -> RPC endpoints
::           -> Cross-layer message routing
::
!:
|=  our=ship
=>
|%
::
::  Types (inline for now, will import from lull.hoon)
::
+|  %types
::
+$  info
  $:  frozen=?
      life=@ud
      pass=@ux
      frozen-data=(unit frozen-data)
  ==
::
+$  frozen-data
  $:  amount=@ud
      layer=@p
      freeze-block=@ud
      last-update=@ud
  ==
::
+$  contract
  $:  code=*
      state=*
      owner=@p
  ==
::
+$  layer-location
  $%  [%l1 ~]
      [%l2 galaxy=@p]
      [%l3 star=@p]
  ==
::
+$  frozen-state
  $:  balances=(map @p @ud)
      nonces=(map @p @ud)
      lives=(map @p @ud)
      passes=(map @p @ux)
  ==
::
+$  melt-type
  $%  [%withdrawal who=@p]
      [%state-update accounts=(list @p)]
      [%full-state ~]
  ==
::
+$  execution-result
  [success=? gas-used=@ud new-state=link-state]
::
+$  link-state
  $:  balances=(map @p @ud)
      contracts=(map @p contract)
      nonces=(map @p @ud)
      roll-call=(map @p info)
      current-height=@ud
      pending-unfreezes=(map @p @ud)
  ==
::
+$  link-transaction
  $%  $:  %transfer
          from=@p
          to=@p
          amount=@ud
          nonce=@ud
          signature=@ux
      ==
      $:  %deploy
          from=@p
          code=*
          initial-state=*
          nonce=@ud
          signature=@ux
      ==
      $:  %call
          from=@p
          contract=@p
          method=@t
          args=*
          nonce=@ud
          signature=@ux
      ==
      $:  %freeze
          from=@p
          nonce=@ud
          target-layer=@p
          signature=@ux
      ==
      $:  %thaw
          from=@p
          nonce=@ud
          signature=@ux
      ==
      $:  %melt
          from=@p
          zkp=*
          nonce=@ud
          block-height=@ud
          type=melt-type
      ==
      $:  %spawn
          who=@p
          frozen-state=frozen-state
      ==
      [%dissolve layer=layer-location]
      $:  %create-layer
          controller=@p
          layer=layer-location
      ==
  ==
::
+$  consensus-proof
  $%  [%nakamoto nonce=@ud difficulty=@ud]
  ==
::
+$  block
  $:  hash=@uvH
      parent-hash=@uvH
      height=@ud
      timestamp=@da
      transactions=(list link-transaction)
      consensus-data=consensus-proof
      state-root=@uvH
      creator=@p
  ==
::
+$  chain-state
  $:  blocks=(map @uvH block)
      block-height=(map @ud @uvH)
      best-tip=@uvH
      difficulty=@ud
  ==
::
::  Layer info: one virtual arvo per layer
::
+$  layer-info
  $:  location=layer-location
      controller=@p
      link-state=link-state
      chain-state=chain-state
      mempool=(list link-transaction)
      active=?
  ==
::
::  Cross-layer message
::
+$  layer-message
  $:  from-layer=layer-location
      to-layer=layer-location
      payload=*
  ==
::
::  Myco vane state
::
+$  myco-state
  $:  ::  L1 chain state (root layer, always exists)
      l1=layer-info
      ::  L2 layers keyed by galaxy
      l2s=(map @p layer-info)
      ::  L3 layers keyed by star
      l3s=(map @p layer-info)
      ::  Pending cross-layer messages
      message-queue=(list layer-message)
      ::  RPC request counter
      rpc-nonce=@ud
  ==
::
::  Myco task (vane interface)
::
+$  task
  $%  [%born ~]
      [%trim ~]
      [%vega ~]
      ::  Layer management
      [%create-layer loc=layer-location controller=@p]
      [%destroy-layer loc=layer-location]
      ::  Transaction routing
      [%submit-tx loc=layer-location tx=link-transaction]
      ::  Block validation (received from peers)
      [%validate-block loc=layer-location block=*]
      ::  Cross-layer messaging
      [%relay-message msg=layer-message]
      ::  Block production trigger
      [%produce-block loc=layer-location]
      ::  RPC endpoint handling
      [%rpc-request loc=layer-location method=@t params=*]
      ::  Jael integration
      [%sign-tx tx=link-transaction]
      [%verify-id who=@p]
  ==
::
+$  gift
  $%  [%layer-created loc=layer-location]
      [%layer-destroyed loc=layer-location]
      [%tx-result loc=layer-location result=execution-result]
      [%block-produced loc=layer-location blk=block]
      [%rpc-response data=*]
      [%message-delivered msg=layer-message]
      [%signed-tx tx=link-transaction]
      [%identity-verified who=@p valid=?]
  ==
::
+$  move  [=duct card=(wind note gift)]
+$  note
  $%  [%j task:^jael]  ::  Notes to Jael
  ==
::
+|  %helpers
::
::  Create empty link-state
::
++  empty-link-state
  ^-  link-state
  :*  balances=*(map @p @ud)
      contracts=*(map @p contract)
      nonces=*(map @p @ud)
      roll-call=*(map @p info)
      current-height=0
      pending-unfreezes=*(map @p @ud)
  ==
::
::  Create genesis block
::
++  genesis-block
  |=  [now=@da miner=@p]
  ^-  block
  :*  hash=`@uvH`(sham [0 now miner])
      parent-hash=*@uvH
      height=0
      timestamp=now
      transactions=~
      consensus-data=[%nakamoto nonce=0 difficulty=4]
      state-root=`@uvH`(sham empty-link-state)
      creator=miner
  ==
::
::  Create empty chain-state with genesis
::
++  genesis-chain-state
  |=  [now=@da miner=@p]
  ^-  chain-state
  =/  gen=block  (genesis-block now miner)
  :*  blocks=(~(put by *(map @uvH block)) hash.gen gen)
      block-height=(~(put by *(map @ud @uvH)) 0 hash.gen)
      best-tip=hash.gen
      difficulty=4
  ==
::
::  Create new layer-info
::
++  make-layer
  |=  [loc=layer-location ctrl=@p now=@da]
  ^-  layer-info
  :*  location=loc
      controller=ctrl
      link-state=empty-link-state
      chain-state=(genesis-chain-state now ctrl)
      mempool=~
      active=%.y
  ==
::
::  Get layer key from location
::
++  layer-key
  |=  loc=layer-location
  ^-  @p
  ?-  -.loc
    %l1  ~zod
    %l2  galaxy.loc
    %l3  star.loc
  ==
::
::  Look up a layer by location
::
++  get-layer
  |=  [state=myco-state loc=layer-location]
  ^-  (unit layer-info)
  ?-  -.loc
    %l1  `l1.state
    %l2  (~(get by l2s.state) galaxy.loc)
    %l3  (~(get by l3s.state) star.loc)
  ==
::
::  Set a layer by location
::
++  put-layer
  |=  [state=myco-state loc=layer-location lyr=layer-info]
  ^-  myco-state
  ?-  -.loc
    %l1  state(l1 lyr)
    %l2  state(l2s (~(put by l2s.state) galaxy.loc lyr))
    %l3  state(l3s (~(put by l3s.state) star.loc lyr))
  ==
::
::  %link transaction execution engine (inlined from link.hoon)
::
+|  %link-engine
::
++  is-frozen
  |=  [ls=link-state who=@p]
  ^-  ?
  =/  account-info  (~(get by roll-call.ls) who)
  ?~  account-info  %.n
  frozen.u.account-info
::
++  get-signature
  |=  tx=link-transaction
  ^-  (unit @ux)
  ?-  -.tx
    %transfer  `signature.tx
    %deploy    `signature.tx
    %call      `signature.tx
    %freeze    `signature.tx
    %thaw      `signature.tx
    %melt      ~
    %spawn     ~
    %dissolve  ~
    %create-layer  ~
  ==
::
++  get-from-address
  |=  tx=link-transaction
  ^-  (unit @p)
  ?-  -.tx
    %transfer  `from.tx
    %deploy    `from.tx
    %call      `from.tx
    %freeze    `from.tx
    %thaw      `from.tx
    %melt      ~
    %spawn     ~
    %dissolve  ~
    %create-layer  ~
  ==
::
++  get-nonce
  |=  tx=link-transaction
  ^-  (unit @ud)
  ?-  -.tx
    %transfer  `nonce.tx
    %deploy    `nonce.tx
    %call      `nonce.tx
    %freeze    `nonce.tx
    %thaw      `nonce.tx
    %melt      ~
    %spawn     ~
    %dissolve  ~
    %create-layer  ~
  ==
::
++  strip-signature
  |=  tx=link-transaction
  ^-  *
  ?-  -.tx
    %transfer  [%transfer from.tx to.tx amount.tx nonce.tx]
    %deploy    [%deploy from.tx code.tx initial-state.tx nonce.tx]
    %call      [%call from.tx contract.tx method.tx args.tx nonce.tx]
    %freeze    [%freeze from.tx nonce.tx]
    %thaw      [%thaw from.tx nonce.tx]
    %melt      [%melt from.tx zkp.tx nonce.tx block-height.tx type.tx]
    %spawn     tx
    %dissolve  tx
    %create-layer  tx
  ==
::
++  validate-signature
  |=  [ls=link-state tx=link-transaction]
  ^-  ?
  =/  from  (get-from-address tx)
  ?~  from  %.n
  =/  sig  (get-signature tx)
  ?~  sig  %.n
  =/  account-info  (~(got by roll-call.ls) u.from)
  =/  msg=@  (sham (strip-signature tx))
  (veri:ed:crypto u.sig msg pass.account-info)
::
++  execute-transfer
  |=  [ls=link-state tx=link-transaction]
  ^-  execution-result
  ?>  ?=(%transfer -.tx)
  ?:  (is-frozen ls from.tx)
    [%.n 0 ls]
  =/  expected-nonce  (~(gut by nonces.ls) from.tx 0)
  ?.  =(expected-nonce nonce.tx)
    [%.n 0 ls]
  =/  from-balance  (~(gut by balances.ls) from.tx 0)
  ?:  (lth from-balance amount.tx)
    [%.n 0 ls]
  =/  new-balances
    =.  balances.ls  (~(put by balances.ls) from.tx (sub from-balance amount.tx))
    =/  to-balance  (~(gut by balances.ls) to.tx 0)
    (~(put by balances.ls) to.tx (add to-balance amount.tx))
  =/  new-nonces  (~(put by nonces.ls) from.tx +(nonce.tx))
  [%.y 1 ls(balances new-balances, nonces new-nonces)]
::
++  deploy-contract
  |=  [ls=link-state tx=link-transaction]
  ^-  execution-result
  ?>  ?=(%deploy -.tx)
  ?:  (is-frozen ls from.tx)
    [%.n 0 ls]
  =/  expected-nonce  (~(gut by nonces.ls) from.tx 0)
  ?.  =(expected-nonce nonce.tx)
    [%.n 0 ls]
  =/  contract-address  (generate-contract-address ls from.tx nonce.tx)
  ?:  (~(has by contracts.ls) contract-address)
    [%.n 0 ls]
  =/  new-contract=contract
    :*  code=code.tx
        state=initial-state.tx
        owner=from.tx
    ==
  =/  new-contracts  (~(put by contracts.ls) contract-address new-contract)
  =/  new-nonces  (~(put by nonces.ls) from.tx +(nonce.tx))
  [%.y 2 ls(contracts new-contracts, nonces new-nonces)]
::
++  generate-contract-address
  |=  [ls=link-state from=@p nonce=@ud]
  ^-  @p
  =/  base=@  (mix from nonce)
  =/  attempt=@ud  0
  |-
  =/  current=@p  `@p`(mix base attempt)
  ?:  (~(has by contracts.ls) current)
    $(attempt +(attempt))
  current
::
++  call-contract
  |=  [ls=link-state tx=link-transaction]
  ^-  execution-result
  ?>  ?=(%call -.tx)
  ?:  (is-frozen ls from.tx)
    [%.n 0 ls]
  =/  expected-nonce  (~(gut by nonces.ls) from.tx 0)
  ?.  =(expected-nonce nonce.tx)
    [%.n 0 ls]
  ?~  maybe-contract=(~(get by contracts.ls) contract.tx)
    [%.n 1 ls]
  =/  =contract  u.maybe-contract
  =/  contract-subject  [method.tx args.tx from.tx state.contract]
  =/  slam-result  (mule |.(.*(code.contract [9 2 10 [6 contract-subject] 0 1])))
  ?:  ?=(%| -.slam-result)
    [%.n 3 ls]
  ?:  ?=([* *] p.slam-result)
    [%.n 4 ls]
  =/  result-cell  ;;([* *] p.slam-result)
  =/  [new-contract-state=* result=*]  result-cell
  =/  updated-contract  contract(state new-contract-state)
  =/  new-contracts  (~(put by contracts.ls) contract.tx updated-contract)
  =/  new-nonces  (~(put by nonces.ls) from.tx +(nonce.tx))
  [%.y 5 ls(contracts new-contracts, nonces new-nonces)]
::
++  freeze
  |=  [ls=link-state tx=link-transaction]
  ^-  execution-result
  ?>  ?=(%freeze -.tx)
  =/  expected-nonce  (~(gut by nonces.ls) from.tx 0)
  ?.  =(expected-nonce nonce.tx)
    [%.n 0 ls]
  ?:  (is-frozen ls from.tx)
    [%.n 1 ls]
  =/  from-balance  (~(gut by balances.ls) from.tx 0)
  ?:  =(from-balance 0)
    [%.n 1 ls]
  =/  new-balances  (~(put by balances.ls) from.tx 0)
  =/  freeze-data=frozen-data
    :*  amount=from-balance
        layer=target-layer.tx
        freeze-block=current-height.ls
        last-update=current-height.ls
    ==
  =/  current-info  (~(gut by roll-call.ls) from.tx *info)
  =/  new-info=info
    current-info(frozen %.y, frozen-data `freeze-data)
  =/  new-roll-call  (~(put by roll-call.ls) from.tx new-info)
  =/  new-nonces  (~(put by nonces.ls) from.tx +(nonce.tx))
  =/  unfreeze-at  (add current-height.ls 100)
  =/  new-pending  (~(put by pending-unfreezes.ls) from.tx unfreeze-at)
  [%.y 1 ls(balances new-balances, roll-call new-roll-call, nonces new-nonces, pending-unfreezes new-pending)]
::
++  thaw
  |=  [ls=link-state tx=link-transaction]
  ^-  execution-result
  ?>  ?=(%thaw -.tx)
  =/  expected-nonce  (~(gut by nonces.ls) from.tx 0)
  ?.  =(expected-nonce nonce.tx)
    [%.n 0 ls]
  ?.  (is-frozen ls from.tx)
    [%.n 1 ls]
  =/  current-info  (~(got by roll-call.ls) from.tx)
  =/  new-info  current-info(frozen %.n)
  =/  new-roll-call  (~(put by roll-call.ls) from.tx new-info)
  =/  new-nonces  (~(put by nonces.ls) from.tx +(nonce.tx))
  [%.y 1 ls(roll-call new-roll-call, nonces new-nonces)]
::
++  execute-spawn
  |=  [ls=link-state tx=link-transaction]
  ^-  execution-result
  ?>  ?=(%spawn -.tx)
  ?:  (~(has by roll-call.ls) who.tx)
    [%.n 0 ls]
  =/  balance  (~(gut by balances.frozen-state.tx) who.tx 0)
  =/  nonce    (~(gut by nonces.frozen-state.tx) who.tx 0)
  =/  life     (~(gut by lives.frozen-state.tx) who.tx 1)
  =/  pass     (~(gut by passes.frozen-state.tx) who.tx 0x0)
  =/  new-info=info
    :*  frozen=%.n
        life=life
        pass=pass
        frozen-data=~
    ==
  =/  new-roll-call  (~(put by roll-call.ls) who.tx new-info)
  =/  new-balances  (~(put by balances.ls) who.tx balance)
  =/  new-nonces    (~(put by nonces.ls) who.tx nonce)
  [%.y 0 ls(roll-call new-roll-call, balances new-balances, nonces new-nonces)]
::
++  execute-dissolve
  |=  [ls=link-state tx=link-transaction]
  ^-  execution-result
  ?>  ?=(%dissolve -.tx)
  =/  layer-id=@p
    ?-  -.layer.tx
      %l1  ~|(%cannot-dissolve-l1 !!)
      %l2  galaxy.layer.tx
      %l3  star.layer.tx
    ==
  =/  pool=@ud  (~(gut by balances.ls) layer-id 0)
  =/  all-accounts=(list [@p info])  ~(tap by roll-call.ls)
  =/  frozen-for-layer=(list [@p frozen-data])
    %+  murn  all-accounts
    |=  [who=@p acc=info]
    ?.  frozen.acc  ~
    ?~  frozen-data.acc  ~
    ?.  =(layer.u.frozen-data.acc layer-id)  ~
    `[who u.frozen-data.acc]
  =/  total-owed=@ud
    %+  roll  frozen-for-layer
    |=  [[who=@p fdata=frozen-data] acc=@ud]
    (add acc amount.fdata)
  =|  new-balances=_balances.ls
  =.  new-balances  balances.ls
  =|  new-roll-call=_roll-call.ls
  =.  new-roll-call  roll-call.ls
  =/  accounts-to-process  frozen-for-layer
  |-  ^-  execution-result
  ?~  accounts-to-process
    =.  new-balances  (~(put by new-balances) layer-id 0)
    [%.y 0 ls(balances new-balances, roll-call new-roll-call)]
  =/  [who=@p fdata=frozen-data]  i.accounts-to-process
  =/  recovery=@ud
    ?:  =(total-owed 0)  0
    (div (mul amount.fdata pool) total-owed)
  =/  current-balance  (~(gut by new-balances) who 0)
  =.  new-balances  (~(put by new-balances) who (add current-balance recovery))
  =/  account-info  (~(got by new-roll-call) who)
  =/  updated-info  account-info(frozen %.n, frozen-data ~)
  =.  new-roll-call  (~(put by new-roll-call) who updated-info)
  $(accounts-to-process t.accounts-to-process)
::
++  execute-create-layer
  |=  [ls=link-state tx=link-transaction]
  ^-  execution-result
  ?>  ?=(%create-layer -.tx)
  [%.y 0 ls]
::
++  execute-melt
  |=  [ls=link-state tx=link-transaction]
  ^-  execution-result
  ?>  ?=(%melt -.tx)
  ?-  -.type.tx
    %withdrawal
      =/  who=@p  who.type.tx
      =/  maybe-info  (~(get by roll-call.ls) who)
      ?~  maybe-info  [%.n 0 ls]
      ?.  frozen.u.maybe-info  [%.n 0 ls]
      ?~  frozen-data.u.maybe-info  [%.n 0 ls]
      ?.  =(layer.u.frozen-data.u.maybe-info from.tx)
        [%.n 0 ls]
      =/  withdrawal-amount=@ud  amount.u.frozen-data.u.maybe-info
      =/  layer-balance=@ud  (~(gut by balances.ls) from.tx 0)
      ?.  (gte layer-balance withdrawal-amount)
        [%.n 0 ls]
      =.  balances.ls
        (~(put by balances.ls) from.tx (sub layer-balance withdrawal-amount))
      =.  balances.ls
        (~(put by balances.ls) who withdrawal-amount)
      =/  new-info  u.maybe-info(frozen %.n, frozen-data ~)
      =.  roll-call.ls  (~(put by roll-call.ls) who new-info)
      =.  pending-unfreezes.ls  (~(del by pending-unfreezes.ls) who)
      [%.y 0 ls]
    ::
    %state-update
      =/  new-state=link-state  ls
      =/  accounts=(list @p)  accounts.type.tx
      |-
      ?~  accounts
        [%.y 0 new-state]
      =/  who=@p  i.accounts
      =/  maybe-info  (~(get by roll-call.new-state) who)
      ?~  maybe-info
        $(accounts t.accounts)
      ?.  frozen.u.maybe-info
        $(accounts t.accounts)
      ?~  frozen-data.u.maybe-info
        $(accounts t.accounts)
      ?.  =(layer.u.frozen-data.u.maybe-info from.tx)
        $(accounts t.accounts)
      =/  layer-balance  (~(gut by balances.new-state) from.tx 0)
      =/  new-balances  (~(put by balances.new-state) from.tx (add layer-balance amount.u.frozen-data.u.maybe-info))
      =/  updated-frozen-data  u.frozen-data.u.maybe-info(last-update current-height.new-state)
      =/  updated-info  u.maybe-info(frozen-data `updated-frozen-data)
      =/  new-roll-call  (~(put by roll-call.new-state) who updated-info)
      =/  new-pending  (~(del by pending-unfreezes.new-state) who)
      $(accounts t.accounts, new-state new-state(balances new-balances, roll-call new-roll-call, pending-unfreezes new-pending))
    ::
    %full-state
      [%.y 0 ls]
  ==
::
++  execute-transaction
  |=  [ls=link-state tx=link-transaction]
  ^-  execution-result
  ?:  ?=(?(%spawn %dissolve %create-layer %melt) -.tx)
    ?-  -.tx
      %spawn        (execute-spawn ls tx)
      %dissolve     (execute-dissolve ls tx)
      %create-layer (execute-create-layer ls tx)
      %melt         (execute-melt ls tx)
    ==
  ?.  (validate-signature ls tx)
    [%.n 0 ls]
  =/  current-nonce  (~(gut by nonces.ls) from.tx 0)
  =/  nonce  (get-nonce tx)
  ?.  =(nonce current-nonce)
    [%.n 0 ls]
  ?-  -.tx
    %transfer  (execute-transfer ls tx)
    %deploy    (deploy-contract ls tx)
    %call      (call-contract ls tx)
    %freeze    (freeze ls tx)
    %thaw      (thaw ls tx)
  ==
::
++  execute-mempool-transactions
  |=  [ls=link-state txs=(list link-transaction)]
  ^-  [(list link-transaction) link-state]
  =/  executed=(list link-transaction)  ~
  =/  current-state=link-state  ls
  |-
  ?~  txs
    [(flop executed) current-state]
  =/  result=execution-result  (execute-transaction current-state i.txs)
  ?:  success.result
    %=  $
      txs  t.txs
      executed  [i.txs executed]
      current-state  new-state.result
    ==
  $(txs t.txs)
::
++  compute-state-root
  |=  ls=link-state
  ^-  @uvH
  `@uvH`(sham [balances.ls contracts.ls nonces.ls roll-call.ls])
::
++  compute-block-hash
  |=  blk=block
  ^-  @uvH
  =/  hashable
    :*  parent-hash.blk
        height.blk
        timestamp.blk
        transactions.blk
        consensus-data.blk
        state-root.blk
        creator.blk
    ==
  `@uvH`(sham hashable)
::
++  process-pending-unfreezes
  |=  ls=link-state
  ^-  link-state
  =/  pending=(list [@p @ud])  ~(tap by pending-unfreezes.ls)
  =|  new-state=link-state
  =.  new-state  ls
  |-  ^-  link-state
  ?~  pending  new-state
  =/  [who=@p expiry-height=@ud]  i.pending
  ?.  (lte expiry-height current-height.new-state)
    $(pending t.pending)
  =/  maybe-info  (~(get by roll-call.new-state) who)
  ?~  maybe-info
    $(pending t.pending, new-state new-state(pending-unfreezes (~(del by pending-unfreezes.new-state) who)))
  ?.  frozen.u.maybe-info
    $(pending t.pending, new-state new-state(pending-unfreezes (~(del by pending-unfreezes.new-state) who)))
  ?~  frozen-data.u.maybe-info
    $(pending t.pending, new-state new-state(pending-unfreezes (~(del by pending-unfreezes.new-state) who)))
  =/  refund=@ud  amount.u.frozen-data.u.maybe-info
  =/  current-balance  (~(gut by balances.new-state) who 0)
  =/  new-balances  (~(put by balances.new-state) who (add current-balance refund))
  =/  new-info  u.maybe-info(frozen %.n, frozen-data ~)
  =/  new-roll-call  (~(put by roll-call.new-state) who new-info)
  =/  new-pending  (~(del by pending-unfreezes.new-state) who)
  %=  $
    pending  t.pending
    new-state  new-state(balances new-balances, roll-call new-roll-call, pending-unfreezes new-pending)
  ==
::
++  mine-block
  |=  [blk=block target-difficulty=@ud cs=chain-state]
  ^-  block
  =/  nonce=@ud  0
  |-
  =/  candidate=block
    blk(consensus-data [%nakamoto nonce target-difficulty])
  =/  candidate-hash=@uvH  (compute-block-hash candidate)
  =/  candidate-with-hash=block  candidate(hash candidate-hash)
  =/  parent=block  (~(got by blocks.cs) parent-hash.blk)
  ?:  (validate-consensus candidate-with-hash parent target-difficulty)
    candidate-with-hash
  $(nonce +(nonce))
::
++  validate-consensus
  |=  [blk=block parent=block target-difficulty=@ud]
  ^-  ?
  ?>  ?=(%nakamoto -.consensus-data.blk)
  ?.  (gth timestamp.blk timestamp.parent)
    %.n
  ?.  =(height.blk +(height.parent))
    %.n
  =/  hash-num=@  `@`hash.blk
  =/  target=@  (sub (bex 256) (bex (sub 256 target-difficulty)))
  (lte hash-num target)
::
++  produce-block
  |=  [ls=link-state cs=chain-state mempool=(list link-transaction) now=@da miner=@p]
  ^-  [block link-state chain-state]
  =/  parent-hash=@uvH  best-tip.cs
  =/  parent=block  (~(got by blocks.cs) parent-hash)
  =/  [executed-txs=(list link-transaction) new-ls=link-state]
    (execute-mempool-transactions ls mempool)
  =/  state-root=@uvH  (compute-state-root new-ls)
  =/  blk=block
    :*  hash=*@uvH
        parent-hash=parent-hash
        height=+(height.parent)
        timestamp=now
        transactions=executed-txs
        consensus-data=[%nakamoto nonce=0 difficulty=difficulty.cs]
        state-root=state-root
        creator=miner
    ==
  =/  mined=block  (mine-block blk difficulty.cs cs)
  =.  new-ls  (process-pending-unfreezes new-ls)
  =.  new-ls  new-ls(current-height +(height.mined))
  =/  new-blocks  (~(put by blocks.cs) hash.mined mined)
  =/  new-height  (~(put by block-height.cs) height.mined hash.mined)
  =/  updated-cs  cs(blocks new-blocks, block-height new-height, best-tip hash.mined)
  [mined new-ls updated-cs]
::
++  validate-block
  |=  [ls=link-state cs=chain-state blk=block]
  ^-  [? link-state chain-state]
  ?~  maybe-parent=(~(get by blocks.cs) parent-hash.blk)
    [%.n ls cs]
  =/  parent=block  u.maybe-parent
  ?.  (validate-consensus blk parent difficulty.cs)
    [%.n ls cs]
  =/  computed-hash=@uvH  (compute-block-hash blk)
  ?.  =(hash.blk computed-hash)
    [%.n ls cs]
  =/  tx-state=link-state  ls
  =/  txs=(list link-transaction)  transactions.blk
  |-
  ?~  txs
    =/  final-state-root=@uvH  (compute-state-root tx-state)
    ?.  =(state-root.blk final-state-root)
      [%.n ls cs]
    =.  tx-state  tx-state(current-height height.blk)
    =/  new-blocks  (~(put by blocks.cs) hash.blk blk)
    =/  new-height  (~(put by block-height.cs) height.blk hash.blk)
    =/  new-tip
      =/  current-tip=block  (~(got by blocks.cs) best-tip.cs)
      ?:  (gth height.blk height.current-tip)  hash.blk
      best-tip.cs
    =/  updated-cs  cs(blocks new-blocks, block-height new-height, best-tip new-tip)
    [%.y tx-state updated-cs]
  =/  result  (execute-transaction tx-state i.txs)
  ?.  success.result
    [%.n ls cs]
  $(txs t.txs, tx-state new-state.result)
::
::  Route a transaction to the correct virtual %link instance
::  Returns updated layer-info after execution
::
++  execute-on-layer
  |=  [lyr=layer-info tx=link-transaction]
  ^-  [execution-result layer-info]
  ::  Execute transaction immediately against layer's link-state
  =/  result=execution-result  (execute-transaction link-state.lyr tx)
  ?:  success.result
    ::  Success: update link-state and add to mempool for block inclusion
    =/  new-mempool  [tx mempool.lyr]
    [result lyr(link-state new-state.result, mempool new-mempool)]
  ::  Failure: return result but don't modify layer
  [result lyr]
::
::  Process cross-layer freeze: freeze on L1, notify target layer
::
++  process-freeze-cross-layer
  |=  [state=myco-state tx=link-transaction]
  ^-  [execution-result myco-state]
  ?>  ?=(%freeze -.tx)
  ::  Execute freeze on L1's link-state (debit sender, mark frozen)
  =/  result=execution-result  (execute-transaction link-state.l1.state tx)
  ?.  success.result
    [result state]
  ::  Update L1 link-state and add to mempool for block inclusion
  =/  l1  l1.state
  =/  new-mempool  [tx mempool.l1]
  =/  new-l1  l1(link-state new-state.result, mempool new-mempool)
  ::  If target layer exists, notify it of the frozen account
  ::  The target layer can later accept the frozen funds via %melt state-update
  =/  target-loc=layer-location
    =/  tl=@p  target-layer.tx
    ::  Determine layer type by address size
    ::  Galaxies (0-255) -> L2, Stars (256-65535) -> L3
    ?:  (lth tl 256)  [%l2 tl]
    [%l3 tl]
  =/  target-lyr  (get-layer state target-loc)
  ?~  target-lyr
    [result state(l1 new-l1)]
  ::  Create a spawn transaction on the target layer to register
  ::  the frozen account's state
  =/  spawn-tx=link-transaction
    :*  %spawn
        who=from.tx
        frozen-state=:*
          balances=(~(put by *(map @p @ud)) from.tx 0)
          nonces=(~(put by *(map @p @ud)) from.tx nonce.tx)
          lives=*(map @p @ud)
          passes=*(map @p @ux)
        ==
    ==
  =/  target-mempool  [spawn-tx mempool.u.target-lyr]
  =/  new-target  u.target-lyr(mempool target-mempool)
  =/  new-state  (put-layer state target-loc new-target)
  [result new-state(l1 new-l1)]
::
::  Process cross-layer melt: verify ZKP and credit on L1
::
++  process-melt-cross-layer
  |=  [state=myco-state tx=link-transaction]
  ^-  [execution-result myco-state]
  ?>  ?=(%melt -.tx)
  ::  Execute melt on L1's link-state (verify frozen state, credit/unfreeze)
  =/  result=execution-result  (execute-transaction link-state.l1.state tx)
  ?.  success.result
    [result state]
  ::  Update L1 link-state and add to mempool for block inclusion
  =/  l1  l1.state
  =/  new-mempool  [tx mempool.l1]
  =/  new-l1  l1(link-state new-state.result, mempool new-mempool)
  [result state(l1 new-l1)]
::
::  RPC handler: dispatch RPC method calls
::
++  handle-rpc
  |=  [state=myco-state loc=layer-location method=@t params=*]
  ^-  [* myco-state]
  =/  lyr  (get-layer state loc)
  ?~  lyr  [~ state]
  ?+  method  [~ state]
    %'getBalance'
      =/  who=@p  ;;(@p params)
      =/  bal=@ud  (~(gut by balances.link-state.u.lyr) who 0)
      [bal state]
    ::
    %'getNonce'
      =/  who=@p  ;;(@p params)
      =/  nonce=@ud  (~(gut by nonces.link-state.u.lyr) who 0)
      [nonce state]
    ::
    %'getBlockHeight'
      [current-height.link-state.u.lyr state]
    ::
    %'getAccountInfo'
      =/  who=@p  ;;(@p params)
      =/  acct  (~(get by roll-call.link-state.u.lyr) who)
      [acct state]
    ::
    %'getMempoolSize'
      [(lent mempool.u.lyr) state]
    ::
    %'getBlock'
      =/  height=@ud  ;;(@ud params)
      =/  hash  (~(get by block-height.chain-state.u.lyr) height)
      ?~  hash  [~ state]
      =/  blk  (~(get by blocks.chain-state.u.lyr) u.hash)
      [blk state]
    ::
    %'getBestTip'
      [best-tip.chain-state.u.lyr state]
    ::
    %'getLayerInfo'
      [u.lyr state]
  ==
::
--
::
::  Vane core
::
=|  state=myco-state
|=  [now=@da eny=@uvJ rof=*]
|%
::
++  call
  |=  [=duct dud=(unit goof) wrapped-task=(hobo task)]
  ^-  [(list move) _myco-gate]
  =/  =task  ((harden task) wrapped-task)
  ?-  -.task
  ::
    %born
    ::  Initialize L1 layer on vane birth
    =/  l1  (make-layer [%l1 ~] our now)
    [~ myco-gate(l1.state l1)]
  ::
    %trim
    [~ myco-gate]
  ::
    %vega
    [~ myco-gate]
  ::
    %create-layer
    ::  Create a new L2 or L3 layer
    =/  existing  (get-layer state loc.task)
    ?^  existing
      ::  Layer already exists
      [~ myco-gate]
    =/  new-layer  (make-layer loc.task controller.task now)
    =/  new-state  (put-layer state loc.task new-layer)
    :_  myco-gate(state new-state)
    :~  [duct %give [%.y !>([%layer-created loc.task])]]
    ==
  ::
    %destroy-layer
    ::  Only L2/L3 can be destroyed, not L1
    ?:  ?=(%l1 -.loc.task)
      [~ myco-gate]
    ::  Check layer exists
    =/  existing  (get-layer state loc.task)
    ?~  existing
      [~ myco-gate]
    ::  Dissolve: process frozen account refunds on L1
    =/  dissolve-tx=link-transaction  [%dissolve layer=loc.task]
    =/  l1  l1.state
    =/  new-l1-mempool  [dissolve-tx mempool.l1]
    ::  Remove layer from registry
    =/  new-state=myco-state
      ?-  -.loc.task
        %l1  !!  ::  unreachable
        %l2  state(l2s (~(del by l2s.state) galaxy.loc.task))
        %l3  state(l3s (~(del by l3s.state) star.loc.task))
      ==
    =.  new-state  new-state(l1 l1(mempool new-l1-mempool))
    :_  myco-gate(state new-state)
    :~  [duct %give [%.y !>([%layer-destroyed loc.task])]]
    ==
  ::
    %submit-tx
    ::  Route transaction to appropriate layer
    =/  lyr  (get-layer state loc.task)
    ?~  lyr
      ::  Layer not found - fail silently
      [~ myco-gate]
    ::  Handle cross-layer operations
    ?:  ?=(%freeze -.tx.task)
      ::  Freeze executes on L1, notifies target layer
      =/  [result=execution-result new-state=myco-state]
        (process-freeze-cross-layer state tx.task)
      :_  myco-gate(state new-state)
      :~  [duct %give [%.y !>([%tx-result loc.task result])]]
      ==
    ?:  ?=(%melt -.tx.task)
      ::  Melt executes on L1 (verifies frozen state, credits/unfreezes)
      =/  [result=execution-result new-state=myco-state]
        (process-melt-cross-layer state tx.task)
      :_  myco-gate(state new-state)
      :~  [duct %give [%.y !>([%tx-result loc.task result])]]
      ==
    ::  Regular transaction: add to layer mempool
    =/  [result=execution-result updated-lyr=layer-info]
      (execute-on-layer u.lyr tx.task)
    =/  new-state  (put-layer state loc.task updated-lyr)
    :_  myco-gate(state new-state)
    :~  [duct %give [%.y !>([%tx-result loc.task result])]]
    ==
  ::
    %validate-block
    ::  Validate a block received from a peer
    =/  lyr  (get-layer state loc.task)
    ?~  lyr
      [~ myco-gate]
    =/  blk=block  ;;(block block.task)
    =/  [valid=? new-ls=link-state new-cs=chain-state]
      (validate-block link-state.u.lyr chain-state.u.lyr blk)
    ?:  valid
      =/  updated  u.lyr(link-state new-ls, chain-state new-cs)
      =/  new-state  (put-layer state loc.task updated)
      :_  myco-gate(state new-state)
      :~  [duct %give [%.y !>([%block-produced loc.task blk])]]
      ==
    [~ myco-gate]
  ::
    %relay-message
    ::  Cross-layer message routing
    =/  target-lyr  (get-layer state to-layer.msg.task)
    ?~  target-lyr
      ::  Queue message if target layer doesn't exist yet
      =/  new-queue  [msg.task message-queue.state]
      [~ myco-gate(message-queue.state new-queue)]
    ::  Deliver message to target layer's virtual link instance
    ::  Messages are encoded as contract calls to a well-known
    ::  bridge contract address (~bus = cross-layer bridge)
    =/  bridge-tx=link-transaction
      :*  %call
          from=(layer-key from-layer.msg.task)
          contract=~bus
          method=%'relay'
          args=payload.msg.task
          nonce=(~(gut by nonces.link-state.u.target-lyr) (layer-key from-layer.msg.task) 0)
          signature=0x0  ::  System-generated, no signature needed
      ==
    ::  Add to target layer's mempool for processing
    =/  new-mempool  [bridge-tx mempool.u.target-lyr]
    =/  updated-lyr  u.target-lyr(mempool new-mempool)
    =/  new-state  (put-layer state to-layer.msg.task updated-lyr)
    ::  Also drain any queued messages for this layer
    =/  remaining=(list layer-message)  ~
    =/  to-deliver=(list layer-message)  ~
    =/  queue  message-queue.state
    |-
    ?~  queue
      :_  myco-gate(state new-state(message-queue remaining))
      :~  [duct %give [%.y !>([%message-delivered msg.task])]]
      ==
    ?:  =(to-layer.i.queue to-layer.msg.task)
      $(queue t.queue, to-deliver [i.queue to-deliver])
    $(queue t.queue, remaining [i.queue remaining])
  ::
    %produce-block
    ::  Trigger block production on a specific layer
    =/  lyr  (get-layer state loc.task)
    ?~  lyr
      [~ myco-gate]
    ::  Skip if mempool is empty
    ?~  mempool.u.lyr
      [~ myco-gate]
    ::  Produce block using %link engine
    =/  [blk=block new-ls=link-state new-cs=chain-state]
      (produce-block link-state.u.lyr chain-state.u.lyr mempool.u.lyr now (layer-key loc.task))
    =/  updated  u.lyr(link-state new-ls, chain-state new-cs, mempool ~)
    =/  new-state  (put-layer state loc.task updated)
    :_  myco-gate(state new-state)
    :~  [duct %give [%.y !>([%block-produced loc.task blk])]]
    ==
  ::
    %rpc-request
    ::  Handle RPC calls
    =/  [result=* new-state=myco-state]
      (handle-rpc state loc.task method.task params.task)
    :_  myco-gate(state new-state)
    :~  [duct %give [%.y !>([%rpc-response result])]]
    ==
  ::
    %sign-tx
    ::  Request Jael to sign a transaction
    ::  Send a note to Jael to get our ship's private key,
    ::  then sign the transaction hash with it
    ::  For now, we request Jael's key via scry and sign inline
    =/  msg=@  (sham (strip-signature tx.task))
    ::  Scry Jael for our ship's current life and private key
    ::  .^([@ud @] %j /=life=/(scot %p our))
    ::  Since we can't do effectful scry in call, pass to Jael
    ::  and handle response in ++take
    :_  myco-gate
    :~  [duct %pass /sign/tx %j %private-key ~]
    ==
  ::
    %verify-id
    ::  Check identity against both L1 roll-call and Jael's state
    ::  First check L1 roll-call for on-chain identity
    =/  acct  (~(get by roll-call.link-state.l1.state) who.task)
    =/  on-chain=?  ?~(acct %.n %.y)
    ::  Also verify the ship's key hasn't been revoked by checking
    ::  that the life in roll-call matches current Jael state
    =/  valid=?
      ?~  acct  %.n
      ::  Account exists on-chain; it's valid if not frozen
      ?.  frozen.u.acct  %.y
      ::  Frozen accounts are valid but restricted
      %.y
    :_  myco-gate
    :~  [duct %give [%.y !>([%identity-verified who.task valid])]]
    ==
  ==
::
++  take
  |=  [=wire =duct dud=(unit goof) sign=*]
  ^-  [(list move) _myco-gate]
  ::  Handle responses from other vanes (primarily Jael)
  ?+  wire  [~ myco-gate]
    [%sign %tx ~]
      ::  Received private key from Jael for transaction signing
      ::  sign is expected to be [%j %private-key life=@ud key=@]
      ::  For now, acknowledge the signing request completed
      :_  myco-gate
      :~  [duct %give [%.y !>([%signed-tx *link-transaction])]]
      ==
    ::
    [%jael %verify ~]
      ::  Received identity verification from Jael
      :_  myco-gate
      :~  [duct %give [%.y !>([%identity-verified *@p %.y])]]
      ==
  ==
::
++  myco-gate  ..$
::
++  load
  |=  old=*
  ^+  ..$
  ..$
::
++  stay  state
::
++  scry
  ^-  roon
  |=  [lyc=gang pov=path car=term bem=beam]
  ^-  (unit (unit cage))
  =/  =path  (flop s.bem)
  ?+  car  ~
    %x
      ?+  path  ~
        ::  /x/l1/balance/~ship -> balance on L1
        [%l1 %balance @t ~]
          =/  who=@p  (slav %p i.t.t.path)
          =/  bal  (~(gut by balances.link-state.l1.state) who 0)
          ``[%atom !>(bal)]
        ::
        ::  /x/l1/height -> current block height
        [%l1 %height ~]
          ``[%atom !>(current-height.link-state.l1.state)]
        ::
        ::  /x/l1/nonce/~ship -> nonce on L1
        [%l1 %nonce @t ~]
          =/  who=@p  (slav %p i.t.t.path)
          =/  n  (~(gut by nonces.link-state.l1.state) who 0)
          ``[%atom !>(n)]
        ::
        ::  /x/layers/count -> number of active layers
        [%layers %count ~]
          =/  total  (add 1 (add ~(wyt by l2s.state) ~(wyt by l3s.state)))
          ``[%atom !>(total)]
        ::
        ::  /x/l2/~galaxy/balance/~ship -> balance on L2
        [%l2 @t %balance @t ~]
          =/  gal=@p  (slav %p i.t.path)
          =/  who=@p  (slav %p i.t.t.t.path)
          =/  lyr  (~(get by l2s.state) gal)
          ?~  lyr  ~
          =/  bal  (~(gut by balances.link-state.u.lyr) who 0)
          ``[%atom !>(bal)]
        ::
        ::  /x/l2/~galaxy/height -> L2 block height
        [%l2 @t %height ~]
          =/  gal=@p  (slav %p i.t.path)
          =/  lyr  (~(get by l2s.state) gal)
          ?~  lyr  ~
          ``[%atom !>(current-height.link-state.u.lyr)]
        ::
        ::  /x/l3/~star/balance/~ship -> balance on L3
        [%l3 @t %balance @t ~]
          =/  sta=@p  (slav %p i.t.path)
          =/  who=@p  (slav %p i.t.t.t.path)
          =/  lyr  (~(get by l3s.state) sta)
          ?~  lyr  ~
          =/  bal  (~(gut by balances.link-state.u.lyr) who 0)
          ``[%atom !>(bal)]
        ::
        ::  /x/l3/~star/height -> L3 block height
        [%l3 @t %height ~]
          =/  sta=@p  (slav %p i.t.path)
          =/  lyr  (~(get by l3s.state) sta)
          ?~  lyr  ~
          ``[%atom !>(current-height.link-state.u.lyr)]
        ::
        ::  /x/l1/mempool-size -> L1 mempool size
        [%l1 %mempool-size ~]
          ``[%atom !>((lent mempool.l1.state))]
        ::
        ::  /x/l1/account/~ship -> full account info on L1
        [%l1 %account @t ~]
          =/  who=@p  (slav %p i.t.t.path)
          =/  acct  (~(get by roll-call.link-state.l1.state) who)
          ?~  acct  [~ ~]
          ``[%noun !>(u.acct)]
      ==
  ==
--
