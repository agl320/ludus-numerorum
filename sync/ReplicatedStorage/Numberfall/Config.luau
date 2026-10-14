-- Shared tuning. No asset IDs, UI copy or combat numbers are scattered across services.
return {
    CodeMin = 1000, CodeMax = 9999, Digits = 4,
    MissCooldown = 1.1, HitCooldown = 0.18, RespawnSeconds = 3,
    -- per elimination; bots pay much less than players: BotCoins each, only for the first BotCoinsCap bots in a round,
    -- and winning a round with no other real players in it pays BotWinCoins instead of the full win bonus
    Rewards = {Coins = 25, XP = 75, BotCoins = 4, BotXP = 20, BotCoinsCap = 12, BotWinCoins = 20},
    RoundSeconds = 180, MinPlayers = 2, Lives = 3, LobbySeconds = 15, LobbyStartSeconds = 25, IntermissionSeconds = 8, ResultsSeconds = 10, ScoreLimit = 30,
    WalkSpeed = 24, JumpPower = 53, FeedLifetime = 6, FeedRows = 5,
    -- Evade-style movement (ParkourController). Speeds in studs/s.
    Movement = {SprintSpeed = 32, GroundAccel = 12, Friction = 7, OverspeedFriction = 2.2, StopSpeed = 10, LandGrace = 0.12,
        AirAccel = 14, AirWishCap = 3.5, AirTurn = 2.6, MaxSpeed = 80,
        JumpBuffer = 0.14, CoyoteTime = 0.12, AutoHop = true, AirJumps = 1, AirJumpPower = 60, AirJumpTurn = 50, AirJumpPush = 14, AirJumpCooldown = 1.2,
        CrouchSpeedScale = 0.5, DashSpeed = 58, DashTime = 0.17, DashCooldown = 1,
        WallJumps = 3, WallJumpPush = 26, WallJumpPower = 42, WallJumpReach = 2.4, WallBounceScale = 0.9, WallBounceUp = 34,
        ClimbSpeed = 19, ClimbWalkSpeed = 30, WallClimbSpeed = 18,
        SlideMinSpeed = 12, SlideBoost = 9, SlideCooldown = 1.1, SlideRestTime = 0.22, SlideFriction = 9, SlideGravity = 0.6, SlideSteer = 1.3,
        SlideEndSpeed = 10, SlideMinTime = 0.25, SlideTouchTime = 1.3, SlideJumpBoost = 4, SlideJumpCooldown = 0.5, TrimpScale = 0.85,
        SlideMaxSpeed = 80, SlideSpeed = 40},
    -- Roblox animation pack ids applied to every character's Animate script (CharacterService).
    Animations = {Run = 656118852, Walk = 2510202577, Idle1 = 2510196951, Idle2 = 2510197257, Fall = 2510195892, Jump = 656117878, Climb = 656114359},
    -- field of view: fixed (no setting), and never above MaxFOV -- sprinting / sliding open it a little up to the cap
    Feel = {BaseFOV = 74, SprintFOV = 78, SlideFOV = 80, SpeedFOV = 2, MaxFOV = 80, DashFOV = 12, MotionScale = 0.65,
        ComboWindow = 4, EffectRange = 180, MaxBursts = 8, MaxVoices = 32},
    Ragdoll = {Push = 27, Lift = 13, Spin = 3, FadeSeconds = 0.55},
    ForeheadDistance = 55, TargetDistance = 30, FrontDot = 0.05,
    -- LED visor number display (ServerScriptService.VisorDisplay). HeightOffset is a fraction of head height.
    Visor = {LEDColor = {255, 38, 48}, Brightness = 2, HeightOffset = 0.2, DigitSheet = ""},
    Teams = {
        FFA = {RGB = {110,190,230}, Spawn = {0,4,0}},
        RED = {BrickColor = 21, RGB = {244, 101, 84}, Spawn = {-76, 4, 0}},
        BLUE = {BrickColor = 23, RGB = {89, 173, 248}, Spawn = {76, 4, 0}},
    },
    -- Paths verified against the Roblox client rbxManifest.txt.
    -- Each cue is a layered mix; Duration trims long sources to punchy transients.
    -- Creator Store audio (APM Music / Pro Sound Effects / Daily Sounds). Duration trims each layer.
    Sounds = {
        Digit = {Gap = 0.03, Layers = {{Id = 9119971433, Volume = 0.35, Speed = 1.7, Duration = 0.07}}},
        -- typing with the Typewriter (gear): a key strike instead of the pen (ProSoundEffects typewriter takes, one picked
        -- at random each press, trimmed to the single strike)
        TypeKey = {Gap = 0.03, Vary = {Pitch = 0.05, Volume = 0.12},
            Layers = {{Id = 9120300066, Volume = 0.55, Speed = 1, Duration = 0.2}},
            Variants = {
                {{Id = 9120300134, Volume = 0.55, Speed = 1, Duration = 0.2}},
                {{Id = 9120299508, Volume = 0.5, Speed = 1, Duration = 0.16}},
                {{Id = 9120299595, Volume = 0.5, Speed = 1, Duration = 0.16}},
                {{Id = 9120299710, Volume = 0.5, Speed = 1, Duration = 0.16}},
                {{Id = 9120299839, Volume = 0.5, Speed = 1, Duration = 0.16}},
            }},
        -- typing on the Keyboard (gear): creamy linear switches, single strokes cut from "Creamy Keyboard Typing"
        -- (91656373864470) and one "Creamy Keyboard Sound Effect" take (102855535543930), one picked at random each press
        Switch = {Gap = 0.03, Vary = {Pitch = 0.04, Volume = 0.1},
            Layers = {{Id = 91656373864470, Volume = 0.6, Speed = 1, Start = 0.49, Duration = 0.13, FadeOut = 0.02}},
            Variants = {
                {{Id = 91656373864470, Volume = 0.6, Speed = 1, Start = 1.24, Duration = 0.11, FadeOut = 0.02}},
                {{Id = 91656373864470, Volume = 0.65, Speed = 1, Start = 2.185, Duration = 0.07, FadeOut = 0.02}},
                {{Id = 91656373864470, Volume = 0.6, Speed = 1, Start = 2.49, Duration = 0.055, FadeOut = 0.02}},
                {{Id = 91656373864470, Volume = 0.6, Speed = 1, Start = 3.68, Duration = 0.05, FadeOut = 0.02}},
                {{Id = 91656373864470, Volume = 0.6, Speed = 1, Start = 0.33, Duration = 0.08, FadeOut = 0.02}},
                {{Id = 91656373864470, Volume = 0.65, Speed = 1, Start = 0.752, Duration = 0.12, FadeOut = 0.02}},
                {{Id = 91656373864470, Volume = 0.65, Speed = 1, Start = 1.83, Duration = 0.09, FadeOut = 0.02}},
                {{Id = 102855535543930, Volume = 0.45, Speed = 1, Start = 0.115, Duration = 0.06, FadeOut = 0.02}},
            }},
        Submit = {Layers = {
            {Id = 9126283592, Volume = 0.4, Speed = 1.35, Duration = 0.35},
            {Id = 106984966606682, Volume = 0.22, Speed = 0.7, Duration = 0.15},
        }},
        Miss = {Layers = {
            {Id = 80890994815283, Volume = 0.3, Speed = 0.7, Duration = 0.5, Treble = -6},
            {Id = 1837830314, Volume = 0.35, Speed = 1.4, Duration = 0.5},
        }},
        -- your elimination: a soft, muted tick-thump with a whisper of glass (subtle: it plays a lot)
        Kill = {Layers = {
            {Id = 94978851787238, Volume = 0.22, Speed = 1.2, Duration = 0.5, Treble = -8, FadeOut = 0.2},
            {Id = 9119913393, Volume = 0.07, Speed = 0.9, Duration = 0.35, Treble = -14, Delay = 0.03},
        }},
        -- other players' eliminations nearby (not played for your own, so they don't stack)
        WorldKill = {Gap = 0.05, Layers = {
            {Id = 9119913393, Volume = 0.07, Speed = 0.8, Duration = 0.5, Treble = -14},
            {Id = 1837830213, Volume = 0.11, Speed = 1.2, Duration = 0.8, Treble = -8, FadeOut = 0.3},
        }},
        -- being eliminated: a low, muffled hit fading out (was three loud layers over 2.6 s)
        Death = {Layers = {
            {Id = 130018094603454, Volume = 0.26, Speed = 0.9, Duration = 1.5, Treble = -8, FadeOut = 0.6},
            {Id = 96795857757261, Volume = 0.14, Speed = 0.8, Duration = 0.8, Treble = -10, FadeOut = 0.3},
        }},
        Spawn = {Layers = {{Id = 1837834284, Volume = 0.35, Speed = 1.25, Duration = 2.2}}},
        Round = {Layers = {
            {Id = 77402059079473, Volume = 0.14, Speed = 0.9, Duration = 3.1, FadeIn = 0.18, FadeOut = 0.4, Treble = -12, Bass = 1, Reverb = -10},
            {Id = 77402059079473, Volume = 0.12, Speed = 0.9, Duration = 3.1, Delay = 2.6, FadeIn = 0.18, FadeOut = 0.4, Treble = -12, Bass = 1, Reverb = -10},
            {Id = 77402059079473, Volume = 0.1, Speed = 0.88, Duration = 3.1, Delay = 5.2, FadeIn = 0.18, FadeOut = 1.4, Treble = -13, Bass = 1, Reverb = -8},
        }},
        Countdown = {Layers = {{Id = 136924498052589, Volume = 0.22, Speed = 1, Duration = 3.7, Treble = -6}}},
        -- the match starting (you've just been sent into the arena): one soft, low whoosh (the chime is gone)
        MatchStart = {Gap = 2, Layers = {
            {Id = 9125807267, Volume = 0.14, Speed = 0.85, Duration = 1.0, Treble = -8, FadeOut = 0.4},
        }},
        -- READY UP pressed in the lobby / cancelled
        ReadyUp = {Gap = 0.3, Layers = {
            {Id = 15675059323, Volume = 0.3, Speed = 0.9, Duration = 0.25},
            {Id = 1837834284, Volume = 0.2, Speed = 1.35, Duration = 0.9, Delay = 0.04},
        }},
        ReadyCancel = {Gap = 0.3, Layers = {{Id = 9126229267, Volume = 0.12, Speed = 1.6, Duration = 0.35, Treble = -6}}},
        Results = {Layers = {{Id = 9044902278, Volume = 0.5, Speed = 1, Duration = 3.8}}},
        Slide = {Gap = 0.3, Vary = {Pitch = 0.07, Volume = 0.15}, Layers = {
            -- soft cloth whoosh; Start skips the lead-in so the swell lands with the slide
            {Id = 9125442175, Volume = 0.22, Speed = 1, Start = 0.62, Duration = 0.85, Treble = -3},
        }, Variants = {
            {{Id = 9125442301, Volume = 0.2, Speed = 0.92, Start = 0.9, Duration = 0.85, Treble = -4}},
            {{Id = 9125442175, Volume = 0.2, Speed = 1.1, Start = 0.5, Duration = 0.8, Treble = -2}},
        }},
        Land = {Gap = 0.12, Vary = {Pitch = 0.08, Volume = 0.2}, Layers = {{Id = 77865207099298, Volume = 0.05, Speed = 1, Duration = 0.25, Treble = -4},{Id = 82615619091463, Volume = 0.06, Speed = 0.92, Delay = 0.03, Duration = 0.24, Treble = -6}},
            Variants = {
                {{Id = 82615619091463, Volume = 0.065, Speed = 1.04, Duration = 0.24, Treble = -5}},
                {{Id = 77865207099298, Volume = 0.055, Speed = 0.9, Duration = 0.26, Treble = -5},{Id = 82615619091463, Volume = 0.045, Speed = 1.08, Delay = 0.02, Duration = 0.2, Treble = -7}},
            }},
        Jump = {Gap = 0.08, Vary = {Pitch = 0.08, Volume = 0.15}, Layers = {{Id = 9126283592, Volume = 0.16, Speed = 1.1, Duration = 0.4}},
            Variants = {
                {{Id = 9126283592, Volume = 0.15, Speed = 1.22, Duration = 0.35}},
                {{Id = 9125442301, Volume = 0.13, Speed = 1.35, Start = 1.18, Duration = 0.3, Treble = -3}},
            }},
        AirJump = {Gap = 0.12, Vary = {Pitch = 0.07, Volume = 0.15}, Layers = {
            -- short cloth "fwoomp" taken from the peak of a cloth whoosh
            {Id = 9125442301, Volume = 0.26, Speed = 1.25, Start = 1.12, Duration = 0.5, Treble = -2},
        }, Variants = {
            {{Id = 9125442175, Volume = 0.24, Speed = 1.32, Start = 0.7, Duration = 0.45, Treble = -2}},
            {{Id = 9125442301, Volume = 0.24, Speed = 1.12, Start = 1.05, Duration = 0.5, Treble = -3}},
        }},
        Combo = {Layers = {
            {Id = 130378474223829, Volume = 0.18, Speed = 0.85, Duration = 0.4, Treble = -6},
            {Id = 9044902278, Volume = 0.1, Speed = 1.25, Duration = 0.9, Delay = 0.05, Treble = -6, FadeOut = 0.4},
        }},
        -- menu / UI (MenuSounds): soft so they never get tiring
        UIHover = {Gap = 0.04, Layers = {{Id = 139719503904449, Volume = 0.12, Speed = 1.15, Duration = 0.12}}},
        UIClick = {Gap = 0.05, Layers = {{Id = 15675059323, Volume = 0.28, Speed = 1, Duration = 0.25}}},
        UIOpen = {Gap = 0.15, Layers = {{Id = 9126229267, Volume = 0.14, Speed = 1.35, Duration = 0.45, Treble = -4},{Id = 15675059323, Volume = 0.12, Speed = 0.8, Duration = 0.2}}},
        UIClose = {Gap = 0.15, Layers = {{Id = 9126229267, Volume = 0.1, Speed = 1.7, Duration = 0.35, Treble = -6}}},
        UITab = {Gap = 0.05, Layers = {{Id = 12222076, Volume = 0.25, Speed = 1.25, Duration = 0.3}}},
        Equip = {Gap = 0.1, Layers = {{Id = 18842800748, Volume = 0.32, Speed = 1.05, Duration = 0.6},{Id = 15675059323, Volume = 0.16, Speed = 1.3, Duration = 0.2, Delay = 0.08}}},
        Unequip = {Gap = 0.1, Layers = {{Id = 18842800748, Volume = 0.22, Speed = 0.8, Duration = 0.5, Treble = -4}}},
        Purchase = {Gap = 0.2, Layers = {{Id = 134810204798705, Volume = 0.3, Speed = 1, Duration = 1.2},{Id = 130378474223829, Volume = 0.2, Speed = 1.1, Duration = 0.5, Delay = 0.1}}},
        UIError = {Gap = 0.2, Layers = {{Id = 80890994815283, Volume = 0.18, Speed = 0.9, Duration = 0.35, Treble = -6}}},
        Deploy = {Gap = 0.5, Layers = {{Id = 9125807267, Volume = 0.22, Speed = 1, Duration = 1.2, Treble = -3},{Id = 1837834284, Volume = 0.2, Speed = 0.9, Duration = 1.5, Delay = 0.2}}},
    },
}
