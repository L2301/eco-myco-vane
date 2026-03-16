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
::  Route a transaction to the correct virtual %link instance
::  Returns updated layer-info after execution
::
++  execute-on-layer
  |=  [lyr=layer-info tx=link-transaction]
  ^-  [execution-result layer-info]
  ::  Add transaction to mempool
  =/  new-mempool  [tx mempool.lyr]
  [*execution-result lyr(mempool new-mempool)]
::
::  Process cross-layer freeze: freeze on L1, notify target layer
::
++  process-freeze-cross-layer
  |=  [state=myco-state tx=link-transaction]
  ^-  myco-state
  ?>  ?=(%freeze -.tx)
  ::  Add freeze tx to L1 mempool
  =/  l1  l1.state
  =/  new-mempool  [tx mempool.l1]
  state(l1 l1(mempool new-mempool))
::
::  Process cross-layer melt: verify ZKP and credit on L1
::
++  process-melt-cross-layer
  |=  [state=myco-state tx=link-transaction]
  ^-  myco-state
  ?>  ?=(%melt -.tx)
  ::  Add melt tx to L1 mempool
  =/  l1  l1.state
  =/  new-mempool  [tx mempool.l1]
  state(l1 l1(mempool new-mempool))
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
      ::  Freeze goes to L1 always
      =/  new-state  (process-freeze-cross-layer state tx.task)
      :_  myco-gate(state new-state)
      :~  [duct %give [%.y !>([%tx-result loc.task *execution-result])]]
      ==
    ?:  ?=(%melt -.tx.task)
      ::  Melt goes to L1 always
      =/  new-state  (process-melt-cross-layer state tx.task)
      :_  myco-gate(state new-state)
      :~  [duct %give [%.y !>([%tx-result loc.task *execution-result])]]
      ==
    ::  Regular transaction: add to layer mempool
    =/  [result=execution-result updated-lyr=layer-info]
      (execute-on-layer u.lyr tx.task)
    =/  new-state  (put-layer state loc.task updated-lyr)
    :_  myco-gate(state new-state)
    :~  [duct %give [%.y !>([%tx-result loc.task result])]]
    ==
  ::
    %relay-message
    ::  Cross-layer message routing
    =/  target-lyr  (get-layer state to-layer.msg.task)
    ?~  target-lyr
      ::  Queue message if target layer doesn't exist yet
      =/  new-queue  [msg.task message-queue.state]
      [~ myco-gate(message-queue.state new-queue)]
    ::  Deliver message to target layer
    ::  TODO: actually process message in target's virtual arvo
    :_  myco-gate
    :~  [duct %give [%.y !>([%message-delivered msg.task])]]
    ==
  ::
    %produce-block
    ::  Trigger block production on a specific layer
    =/  lyr  (get-layer state loc.task)
    ?~  lyr
      [~ myco-gate]
    ::  TODO: Call into %link's produce-block
    ::  For now, just clear mempool
    =/  updated  u.lyr(mempool ~)
    =/  new-state  (put-layer state loc.task updated)
    [~ myco-gate(state new-state)]
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
    ::  TODO: Integrate with Jael's key management
    :_  myco-gate
    :~  [duct %give [%.y !>([%signed-tx tx.task])]]
    ==
  ::
    %verify-id
    ::  Check identity against L1 roll-call
    =/  acct  (~(get by roll-call.link-state.l1.state) who.task)
    =/  valid=?  ?~(acct %.n %.y)
    :_  myco-gate
    :~  [duct %give [%.y !>([%identity-verified who.task valid])]]
    ==
  ==
::
++  take
  |=  [=wire =duct dud=(unit goof) sign=*]
  ^-  [(list move) _myco-gate]
  ::  Handle responses from other vanes (primarily Jael)
  [~ myco-gate]
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
      ==
  ==
--
