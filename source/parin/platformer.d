// ---
// Copyright 2024 Alexandros F. G. Kapretsos
// SPDX-License-Identifier: MIT
// Email: alexandroskapretsos@gmail.com
// Project: https://github.com/Kapendev/parin
// Version: v0.0.39
// ---

// TODO: Update all the doc comments here.
// TODO: Add spatial partitioning after testing this in a game.
// TODO: Add one-way collision support for moving walls.
// NOTE: Maybe a world pixel size value could be useful.

/// The `platformer` module provides a pixel-perfect physics engine.
module parin.platformer;

import joka.ascii;
import joka.containers;
import joka.math;
import joka.types;

@safe @nogc nothrow:

alias BaseBoxId = int;
alias ActorBoxId = BaseBoxId;
alias WallBoxId = BaseBoxId;
alias OneWaySide = RideSide;

enum RideSide : ubyte {
    none,
    top,
    left,
    right,
    bottom,
}

struct BoxMover {
    Vec2 direction;
    Vec2 velocity;
    float speed = 1.0f;
    float jump = 0.0f;
    float gravity = 0.0f;
    float gravityFallFactor = 0.7f;
    float acceleration = 0.0f;
    float decelerationFactor = 0.3f;
    bool isUnnormalized;

    @safe @nogc nothrow:

    this(float speed, float jump, float gravity, float acceleration) {
        this.speed = speed;
        this.jump = jump;
        this.gravity = gravity;
        this.acceleration = acceleration;
    }

    bool isSmooth() {
        return acceleration != 0.0f;
    }

    bool isTopDown() {
        return gravity == 0.0f;
    }

    Vec2 move() {
        if (isTopDown) {
            auto tempDirection = isUnnormalized ? direction : direction.normalize();
            if (isSmooth) {
                if (direction.x > 0.0f) {
                    velocity.x = min(velocity.x + tempDirection.x * acceleration, tempDirection.x * speed);
                } else if (direction.x < 0.0f) {
                    velocity.x = max(velocity.x + tempDirection.x * acceleration, tempDirection.x * speed);
                }
                if (velocity.x != tempDirection.x * speed) {
                   velocity.x = lerp(velocity.x, 0.0f, decelerationFactor);
                }
                if (direction.y > 0.0f) {
                    velocity.y = min(velocity.y + tempDirection.y * acceleration, tempDirection.y * speed);
                } else if (direction.y < 0.0f) {
                    velocity.y = max(velocity.y + tempDirection.y * acceleration, tempDirection.y * speed);
                }
                if (velocity.y != tempDirection.y * speed) {
                   velocity.y = lerp(velocity.y, 0.0f, decelerationFactor);
                }
            } else {
                velocity.x = tempDirection.x * speed;
                velocity.y = tempDirection.y * speed;
            }
            velocity.x = velocity.x;
            velocity.y = velocity.y;
        } else {
            if (isSmooth) {
                if (direction.x > 0.0f) {
                    velocity.x = min(velocity.x + acceleration, speed);
                } else if (direction.x < 0.0f) {
                    velocity.x = max(velocity.x - acceleration, -speed);
                }
                if (velocity.x != direction.x * speed) {
                   velocity.x = lerp(velocity.x, 0.0f, decelerationFactor);
                }
            } else {
                velocity.x = direction.x * speed;
            }
            velocity.x = velocity.x;

            if (velocity.y > 0.0f) velocity.y += gravity;
            else velocity.y += gravity * gravityFallFactor;
            if (direction.y < 0.0f) velocity.y = -jump;
        }
        return velocity;
    }
}

struct Box {
    IVec2 position;
    IVec2 size;

    @safe @nogc nothrow:

    pragma(inline, true)
    this(IVec2 position, IVec2 size) {
        this.position = position;
        this.size = size;
    }

    pragma(inline, true)
    this(int x, int y, int w, int h) {
        this(IVec2(x, y), IVec2(w, h));
    }

    pragma(inline, true)
    this(IVec2 position, int w, int h) {
        this(position, IVec2(w, h));
    }

    pragma(inline, true)
    this(int x, int y, IVec2 size) {
        this(IVec2(x, y), size);
    }

    pragma(inline, true)
    Rect toRect() {
        return Rect(position.toVec(), size.toVec());
    }

    bool hasPoint(IVec2 point) {
        return (
            point.x > position.x &&
            point.x < position.x + size.x &&
            point.y > position.y &&
            point.y < position.y + size.y
        );
    }

    bool hasIntersection(Box area) {
        return (
            position.x + size.x > area.position.x &&
            position.x < area.position.x + area.size.x &&
            position.y + size.y > area.position.y &&
            position.y < area.position.y + area.size.y
        );
    }

    /// Returns a string representation with a limited lifetime.
    IStr toStr() {
        return "({}, {}, {}, {})".format(position.x, position.y, size.x, size.y);
    }
}

struct WallBoxProperties {
    Vec2 remainder;
    OneWaySide oneWaySide;
    bool isPassable;
}

struct ActorBoxProperties {
    Vec2 remainder;
    RideSide rideSide;
    bool isRiding;
    bool isPassable;
}

struct BoxWorld {
    List!Box walls;
    List!Box actors;
    List!WallBoxProperties wallsProperties;
    List!ActorBoxProperties actorsProperties;
    List!ActorBoxId squishedIdsBuffer;
    List!BaseBoxId collisionIdsBuffer;

    @safe @nogc nothrow:

    ref Box getWall(WallBoxId id) {
        if (id <= 0) {
            assert(0, "ID `0` is always invalid and represents a box that was never created.");
        } else if (id > walls.length) {
            assert(0, "ID `{}` does not exist.".format(id));
        }
        return walls[id - 1];
    }

    ref Box getActor(ActorBoxId id) {
        if (id <= 0) {
            assert(0, "ID `0` is always invalid and represents a box that was never created.");
        } else if (id > actors.length) {
            assert(0, "ID `{}` does not exist.".format(id));
        }
        return actors[id - 1];
    }

    ref WallBoxProperties getWallProperties(WallBoxId id) {
        if (id <= 0) {
            assert(0, "ID `0` is always invalid and represents a box that was never created.");
        } else if (id > wallsProperties.length) {
            assert(0, "ID `{}` does not exist.".format(id));
        }
        return wallsProperties[id - 1];
    }

    ref ActorBoxProperties getActorProperties(ActorBoxId id) {
        if (id <= 0) {
            assert(0, "ID `0` is always invalid and represents a box that was never created.");
        } else if (id > actorsProperties.length) {
            assert(0, "ID `{}` does not exist.".format(id));
        }
        return actorsProperties[id - 1];
    }

    WallBoxId appendWall(Box box, OneWaySide oneWaySide = OneWaySide.none) {
        walls.append(box);
        wallsProperties.append(WallBoxProperties());
        wallsProperties[$ - 1].oneWaySide = oneWaySide;
        return cast(BaseBoxId) walls.length;
    }

    ActorBoxId appendActor(Box box, RideSide rideSide = RideSide.none) {
        actors.append(box);
        actorsProperties.append(ActorBoxProperties());
        actorsProperties[$ - 1].rideSide = rideSide;
        return cast(BaseBoxId) actors.length;
    }

    WallBoxId hasWallCollision(Box box) {
        foreach (i, wall; walls) {
            if (wall.hasIntersection(box) && !wallsProperties[i].isPassable) return cast(BaseBoxId) (i + 1);
        }
        return 0;
    }

    ActorBoxId hasActorCollision(Box box) {
        foreach (i, actor; actors) {
            if (actor.hasIntersection(box) && !actorsProperties[i].isPassable) return cast(BaseBoxId) (i + 1);
        }
        return 0;
    }

    WallBoxId[] getWallCollisions(Box box) {
        collisionIdsBuffer.clear();
        foreach (i, wall; walls) {
            if (wall.hasIntersection(box) && !wallsProperties[i].isPassable) collisionIdsBuffer.append(cast(BaseBoxId) (i + 1));
        }
        return collisionIdsBuffer[];
    }

    ActorBoxId[] getActorCollisions(Box box) {
        collisionIdsBuffer.clear();
        foreach (i, actor; actors) {
            if (actor.hasIntersection(box) && !actorsProperties[i].isPassable) collisionIdsBuffer.append(cast(BaseBoxId) (i + 1));
        }
        return collisionIdsBuffer[];
    }

    WallBoxId moveActorX(ActorBoxId id, float amount) {
        auto actor = &getActor(id);
        auto properties = &getActorProperties(id);
        properties.remainder.x += amount;

        auto move = cast(int) properties.remainder.x.round();
        if (move == 0) return false;

        int moveSign = move.sign();
        properties.remainder.x -= move;
        while (move != 0) {
            auto tempBox = Box(actor.position + IVec2(moveSign, 0), actor.size);
            auto wallId = hasWallCollision(tempBox);
            if (wallId) {
                // One way stuff.
                auto wall = &getWall(wallId);
                auto wallProperties = &getWallProperties(wallId);
                final switch (wallProperties.oneWaySide) with (OneWaySide) {
                    case none:
                        break;
                    case top:
                    case bottom:
                        wallId = 0;
                        break;
                    case left:
                        if (wall.position.x < actor.position.x || wall.hasIntersection(*actor)) wallId = 0;
                        break;
                    case right:
                        if (wall.position.x > actor.position.x || wall.hasIntersection(*actor)) wallId = 0;
                        break;
                }
            }
            if (!properties.isPassable && wallId) {
                return wallId;
            } else {
                actor.position.x += moveSign;
                move -= moveSign;
            }
        }
        return 0;
    }

    WallBoxId moveActorXTo(ActorBoxId id, float to, float amount) {
        auto actor = &getActor(id);
        auto target = moveTo(cast(float) actor.position.x, to.floor(), amount);
        return moveActorX(id, target - actor.position.x);
    }

    WallBoxId moveActorXToWithSlowdown(ActorBoxId id, float to, float amount, float slowdown) {
        auto actor = &getActor(id);
        auto target = moveToWithSlowdown(cast(float) actor.position.x, to.floor(), amount, slowdown);
        return moveActorX(id, target - actor.position.x);
    }

    WallBoxId moveActorY(ActorBoxId id, float amount) {
        auto actor = &getActor(id);
        auto properties = &getActorProperties(id);
        properties.remainder.y += amount;

        auto move = cast(int) properties.remainder.y.round();
        if (move == 0) return false;

        int moveSign = move.sign();
        properties.remainder.y -= move;
        while (move != 0) {
            auto tempBox = Box(actor.position + IVec2(0, moveSign), actor.size);
            auto wallId = hasWallCollision(tempBox);
            if (wallId) {
                // One way stuff.
                auto wall = &getWall(wallId);
                auto wallProperties = &getWallProperties(wallId);
                final switch (wallProperties.oneWaySide) with (OneWaySide) {
                    case none:
                        break;
                    case left:
                    case right:
                        wallId = 0;
                        break;
                    case top:
                        if (wall.position.y < actor.position.y || wall.hasIntersection(*actor)) wallId = 0;
                        break;
                    case bottom:
                        if (wall.position.y > actor.position.y || wall.hasIntersection(*actor)) wallId = 0;
                        break;
                }
            }
            if (!properties.isPassable && wallId) {
                return wallId;
            } else {
                actor.position.y += moveSign;
                move -= moveSign;
            }
        }
        return 0;
    }

    WallBoxId moveActorYTo(ActorBoxId id, float to, float amount) {
        auto actor = &getActor(id);
        auto target = moveTo(cast(float) actor.position.y, to.floor(), amount);
        return moveActorY(id, target - actor.position.y);
    }

    WallBoxId moveActorYToWithSlowdown(ActorBoxId id, float to, float amount, float slowdown) {
        auto actor = &getActor(id);
        auto target = moveToWithSlowdown(cast(float) actor.position.y, to.floor(), amount, slowdown);
        return moveActorY(id, target - actor.position.y);
    }

    IVec2 moveActor(ActorBoxId id, Vec2 amount) {
        auto result = IVec2();
        result.x = cast(int) moveActorX(id, amount.x);
        result.y = cast(int) moveActorY(id, amount.y);
        return result;
    }

    IVec2 moveActorTo(ActorBoxId id, Vec2 to, Vec2 amount) {
        auto actor = &getActor(id);
        auto target = moveTo(actor.position.toVec(), to.floor(), amount);
        return moveActor(id, target - actor.position.toVec());
    }

    IVec2 moveActorToWithSlowdown(ActorBoxId id, Vec2 to, Vec2 amount, float slowdown) {
        auto actor = &getActor(id);
        auto target = moveToWithSlowdown(actor.position.toVec(), to.floor(), amount, slowdown);
        return moveActor(id, target - actor.position.toVec());
    }

    ActorBoxId[] moveWallX(WallBoxId id, float amount) {
        return moveWall(id, Vec2(amount, 0.0f));
    }

    ActorBoxId[] moveWallXTo(WallBoxId id, float to, float amount) {
        auto wall = &getWall(id);
        auto target = moveTo(cast(float) wall.position.x, to.floor(), amount);
        return moveWallX(id, target - wall.position.x);
    }

    ActorBoxId[] moveWallXToWithSlowdown(WallBoxId id, float to, float amount, float slowdown) {
        auto wall = &getWall(id);
        auto target = moveToWithSlowdown(cast(float) wall.position.x, to.floor(), amount, slowdown);
        return moveWallX(id, target - wall.position.x);
    }

    ActorBoxId[] moveWallY(WallBoxId id, float amount) {
        return moveWall(id, Vec2(0.0f, amount));
    }

    ActorBoxId[] moveWallYTo(WallBoxId id, float to, float amount) {
        auto wall = &getWall(id);
        auto target = moveTo(cast(float) wall.position.y, to.floor(), amount);
        return moveWallY(id, target - wall.position.y);
    }

    ActorBoxId[] moveWallYToWithSlowdown(WallBoxId id, float to, float amount, float slowdown) {
        auto wall = &getWall(id);
        auto target = moveToWithSlowdown(cast(float) wall.position.y, to.floor(), amount, slowdown);
        return moveWallY(id, target - wall.position.y);
    }

    ActorBoxId[] moveWall(WallBoxId id, Vec2 amount) {
        auto wall = &getWall(id);
        auto properties = &getWallProperties(id);
        properties.remainder += amount;

        // NOTE: Will be removed when I want to work on that...
        if (properties.oneWaySide) {
            assert(0, "One-way collisions are not yet supported for moving walls.");
        }

        squishedIdsBuffer.clear();
        auto move = properties.remainder.round().toIVec();
        if (move.x != 0 || move.y != 0) {
            foreach (i, ref actorProperties; actorsProperties) {
                actorProperties.isRiding = false;
                if (!actorProperties.rideSide || actorProperties.isPassable) continue;
                auto rideBox = actors[i];
                final switch (actorProperties.rideSide) with (RideSide) {
                    case none: break;
                    case top: rideBox.position.y += 1; break;
                    case left: rideBox.position.x += 1; break;
                    case right: rideBox.position.x -= 1; break;
                    case bottom: rideBox.position.y -= 1; break;
                }
                actorProperties.isRiding = wall.hasIntersection(rideBox);
            }
        }
        if (move.x != 0) {
            wall.position.x += move.x;
            properties.remainder.x -= move.x;
            if (!properties.isPassable) {
                properties.isPassable = true;
                foreach (i, ref actor; actors) {
                    if (actorsProperties[i].isPassable) continue;
                    if (wall.hasIntersection(actor)) {
                        // Push actor.
                        auto wallLeft = wall.position.x;
                        auto wallRight = wall.position.x + wall.size.x;
                        auto actorLeft = actor.position.x;
                        auto actorRight = actor.position.x + actor.size.x;
                        auto actorPushAmount = (move.x > 0) ? (wallRight - actorLeft) : (wallLeft - actorRight);
                        if (moveActorX(cast(BaseBoxId) (i + 1), actorPushAmount)) {
                            // Squish actor.
                            squishedIdsBuffer.append(cast(BaseBoxId) (i + 1));
                        }
                    } else if (actorsProperties[i].isRiding) {
                        // Carry actor.
                        moveActorX(cast(BaseBoxId) (i + 1), move.x);
                    }
                }
                properties.isPassable = false;
            }
        }
        if (move.y != 0) {
            wall.position.y += move.y;
            properties.remainder.y -= move.y;
            if (!properties.isPassable) {
                properties.isPassable = true;
                foreach (i, ref actor; actors) {
                    if (actorsProperties[i].isPassable) continue;
                    if (wall.hasIntersection(actor)) {
                        // Push actor.
                        auto wallTop = wall.position.y;
                        auto wallBottom = wall.position.y + wall.size.y;
                        auto actorTop = actor.position.y;
                        auto actorBottom = actor.position.y + actor.size.y;
                        auto actorPushAmount = (move.y > 0) ? (wallBottom - actorTop) : (wallTop - actorBottom);
                        if (moveActorY(cast(BaseBoxId) (i + 1), actorPushAmount)) {
                            // Squish actor.
                            squishedIdsBuffer.append(cast(BaseBoxId) (i + 1));
                        }
                    } else if (actorsProperties[i].isRiding) {
                        // Carry actor.
                        moveActorY(cast(BaseBoxId) (i + 1), move.y);
                    }
                }
                properties.isPassable = false;
            }
        }
        return squishedIdsBuffer[];
    }

    ActorBoxId[] moveWallTo(WallBoxId id, Vec2 to, Vec2 amount) {
        auto wall = &getWall(id);
        auto target = moveTo(wall.position.toVec(), to.floor(), amount);
        return moveWall(id, target - wall.position.toVec());
    }

    ActorBoxId[] moveWallToWithSlowdown(WallBoxId id, Vec2 to, Vec2 amount, float slowdown) {
        auto wall = &getWall(id);
        auto target = moveToWithSlowdown(wall.position.toVec(), to.floor(), amount, slowdown);
        return moveWall(id, target - wall.position.toVec());
    }

    void clearWalls() {
        walls.clear();
        wallsProperties.clear();
    }

    void clearActors() {
        actors.clear();
        actorsProperties.clear();
    }

    void clear() {
        clearWalls();
        clearActors();
        squishedIdsBuffer.clear();
        collisionIdsBuffer.clear();
    }

    void reserve(Sz capacity) {
        walls.reserve(capacity);
        actors.reserve(capacity);
        wallsProperties.reserve(capacity);
        actorsProperties.reserve(capacity);
        squishedIdsBuffer.reserve(capacity);
        collisionIdsBuffer.reserve(capacity);
    }

    void free() {
        walls.free();
        actors.free();
        wallsProperties.free();
        actorsProperties.free();
        squishedIdsBuffer.free();
        collisionIdsBuffer.free();
        this = BoxWorld();
    }
}
