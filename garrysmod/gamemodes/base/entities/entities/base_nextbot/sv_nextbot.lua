
--
-- Name: NEXTBOT:BehaveStart
-- Desc: Called to initialize the behaviour.\n\n You shouldn't override this - it's used to kick off the coroutine that runs the bot's behaviour. \n\nThis is called automatically when the NPC is created, there should be no need to call it manually.
-- Arg1: 
-- Ret1:
--
function ENT:BehaveStart()

	local s = self
	self.BehaveThread = coroutine.create( function() self:RunBehaviour() end )
	
end

--
-- Name: NEXTBOT:BehaveUpdate
-- Desc: Called to update the bot's behaviour
-- Arg1: number|interval|How long since the last update
-- Ret1:
--
function ENT:BehaveUpdate( fInterval )

	if ( !self.BehaveThread ) then return end

	local ok, message = coroutine.resume( self.BehaveThread )
	if ( ok == false ) then

		self.BehaveThread = nil
		Msg( self, "error: ", message, "\n" );

	end

end

--
-- Name: NEXTBOT:BodyUpdate
-- Desc: Called to update the bot's animation
-- Arg1:
-- Ret1:
--
function ENT:BodyUpdate()

	--
	-- This helper function does a lot of useful stuff for us. 
	-- It sets the bot's move_x move_y pose parameters, sets their animation speed relative to the ground speed, and calls FrameAdvance.
	--
	self:BodyMoveXY()

end

--
-- Name: NEXTBOT:OnLeaveGround
-- Desc: Called when the bot's feet leave the ground - for whatever reason
-- Arg1:
-- Ret1:
--
function ENT:OnLeaveGround()

	MsgN( "OnLeaveGround" )

end

--
-- Name: NEXTBOT:OnLeaveGround
-- Desc: Called when the bot's feet return to the ground
-- Arg1:
-- Ret1:
--
function ENT:OnLandOnGround()

	MsgN( "OnLandOnGround" )

end

--
-- Name: NEXTBOT:OnStuck
-- Desc: Called when the bot thinks it is stuck
-- Arg1:
-- Ret1:
--
function ENT:OnStuck()

	MsgN( "OnStuck" )

end

--
-- Name: NEXTBOT:OnUnStuck
-- Desc: Called when the bot thinks it is un-stuck
-- Arg1:
-- Ret1:
--
function ENT:OnUnStuck()

	MsgN( "OnUnStuck" )

end

--
-- Name: NEXTBOT:OnInjured
-- Desc: Called when the bot gets hurt
-- Arg1:
-- Ret1:
--
function ENT:OnInjured()

	MsgN( "OnInjured" )

end

--
-- Name: NEXTBOT:OnKilled
-- Desc: Called when the bot gets killed
-- Arg1:
-- Ret1:
--
function ENT:OnKilled( damageinfo )

	self:BecomeRagdoll( damageinfo )

end

--
-- Name: NEXTBOT:OnOtherKilled
-- Desc: Called when someone else or something else has been killed
-- Arg1:
-- Ret1:
--
function ENT:OnOtherKilled()

	MsgN( "OnOtherKilled" )

end


--
-- Name: NextBot:FindSpots
-- Desc: Returns a table of hiding spots.
-- Arg1: table|specs|This table should contain the search info.\n\n * 'type' - the type (either 'hiding')\n * 'pos' - the position to search.\n * 'radius' - the radius to search.\n * 'stepup' - the highest step to step up.\n * 'stepdown' - the highest we can step down without being hurt.
-- Ret1: table|An unsorted table of tables containing\n * 'vector' - the position of the hiding spot\n * 'distance' - the distance to that position
--

function ENT:FindSpots( tbl )

	local tbl = tbl or {}
	
	tbl.pos			= tbl.pos			or self:WorldSpaceCenter()
	tbl.radius		= tbl.radius		or 1000
	tbl.stepdown	= tbl.stepdown		or 20
	tbl.stepup		= tbl.stepup		or 20
	tbl.type		= tbl.type			or 'hiding'

	-- Use a path to find the length
	local path = Path( "Follow" )

	-- Find a bunch of areas within this distance
	local areas = navmesh.Find( tbl.pos, tbl.radius, tbl.stepdown, tbl.stepup )

	local found = {}
	
	-- In each area
	for _, area in pairs( areas ) do

		-- get the spots
		local spots 
		
		if ( tbl.type == 'hiding' ) then spots = area:GetHidingSpots() end

		for k, vec in pairs( spots ) do

			-- Work out the length, and add them to a table
			path:Invalidate()

			path:Compute( self, vec, 1 ) -- TODO: This is bullshit - it's using 'self.pos' not tbl.pos
				
			table.insert( found, { vector = vec, distance = path:GetLength() } )

		end

	end

	return found

end

--
-- Name: NextBot:HandleStuck
-- Desc: Called from Lua when the NPC is stuck. This should only be called from the behaviour coroutine - so if you want to override this function and do something special that yields - then go for it.\n\nYou should always call self.loco:ClearStuck() in this function to reset the stuck status - so it knows it's unstuck.
-- Arg1: 
-- Ret1: 
--
function ENT:HandleStuck()

	--
	-- Clear the stuck status
	--
	self.loco:ClearStuck();

end

--
-- Name: NextBot:MoveToPos
-- Desc: To be called in the behaviour coroutine only! Will yield until the bot has reached the goal or is stuck
-- Arg1: Vector|pos|The position we want to get to
-- Arg2: table|options|A table containing a bunch of tweakable options. See the function definition for more details
-- Ret1: string|Either "failed", "stuck", "timeout" or "ok" - depending on how the NPC got on
--
function ENT:MoveToPos( pos, options )

	local options = options or {}

	local path = Path( "Follow" )
	path:SetMinLookAheadDistance( options.lookahead or 300 )
	path:SetGoalTolerance( options.tolerance or 20 )
	path:Compute( self, pos )

	if ( !path:IsValid() ) then return "failed" end

	while ( path:IsValid() ) do

		path:Update( self )

		-- Draw the path (only visible on listen servers or single player)
		if ( options.draw ) then
			path:Draw()
		end

		-- If we're stuck then call the HandleStuck function and abandon
		if ( self.loco:IsStuck() ) then

			self:HandleStuck();
			
			return "stuck"

		end

		--
		-- If they set maxage on options then make sure the path is younger than it
		--
		if ( options.maxage ) then
			if ( path:GetAge() > options.maxage ) then return "timeout" end
		end

		--
		-- If they set repath then rebuild the path every x seconds
		--
		if ( options.repath ) then
			if ( path:GetAge() > options.repath ) then path:Compute( self, pos ) end
		end

		coroutine.yield()

	end

	return "ok"

end