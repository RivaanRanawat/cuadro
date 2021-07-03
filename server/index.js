const express = require("express");
var http = require("http");
const app = express();
const port = process.env.PORT || 3000;
var server = http.createServer(app);
var io = require("socket.io")(server);
const mongoose = require("mongoose");
const getWord = require("./apis/generateWord");
const Room = require("./models/room");
const dotenv = require("dotenv");

dotenv.config();

//middleware
app.use(express.json());

mongoose
  .connect(process.env.MONGODB_URL, {
    useNewUrlParser: true,
    useUnifiedTopology: true,
    useCreateIndex: true,
    useFindAndModify: false,
  })
  .then(() => {
    console.log("connection succesful");
  })
  .catch((e) => {
    console.log(e);
  });

// sockets

app.get("/", (req, res) => {
  return res.send("HEY Working, lets gooooooo!");
});

io.on("connection", (socket) => {
  console.log("connected");
  console.log(process.env.NODE_ENV);
  console.log(socket.id, "has joined");
  socket.on("test", (data) => {
    console.log(data);
  });

  // white board related sockets
  socket.on("paint", ({ details, roomName }) => {
    io.to(roomName).emit("points", { details: details });
  });

  socket.on("clean-screen", (roomId) => {
    io.to(roomId).emit("clear-screen", "");
  });

  socket.on("stroke-width", (stroke) => {
    io.emit("stroke-width", stroke);
  });

  // game related sockets
  // creating game
  socket.on("create-game", async ({ nickname, name, occupancy, maxRounds }) => {
    try {
      const existingRoom = await Room.findOne({ name });
      if (existingRoom) {
        socket.emit("notCorrectGame", "Room with that name already exists");
        return;
      }
      let room = new Room();
      const word = getWord();
      room.word = word;
      room.name = name;
      room.occupancy = occupancy;
      room.maxRounds = maxRounds;
      let player = {
        socketID: socket.id,
        nickname,
        isPartyLeader: true,
      };
      room.players.push(player);
      room = await room.save();
      socket.join(name);
      io.to(name).emit("updateRoom", room);
    } catch (err) {
      console.log(err);
    }
  });

  // joining game
  socket.on("join-game", async ({ nickname, name }) => {
    try {
      let room = await Room.findOne({ name });
      if (!room) {
        socket.emit("notCorrectGame", "Please enter a valid room name");
        return;
      }
      if (room.isJoin) {
        // waiting for players
        let player = {
          socketID: socket.id,
          nickname,
        };
        room.players.push(player);
        socket.join(name);
        if (room.players.length === room.occupancy) {
          room.isJoin = false;
        }
        room.turn = room.players[room.turnIndex];
        room = await room.save();
        io.to(name).emit("updateRoom", room);
      } else {
        socket.emit(
          "notCorrectGame",
          "The Game is in progress, please try later!"
        );
      }
    } catch (err) {
      console.log(err.toString());
    }
  });

  socket.on("updateScore", async (name) => {
    console.log("update score index");
    const room = await Room.findOne({ name });
    io.to(name).emit("updateScore", room);
  });

  socket.on("change-turn", async (name) => {
    console.log("Change Turn!");
    let room = await Room.findOne({ name });
    let idx = room.turnIndex;
    if (idx + 1 === room.players.length) {
      room.currentRound += 1;
      console.log("current round increase");
    }
    if (room.currentRound <= room.maxRounds) {
      const word = getWord();
      room.word = word;
      room.turnIndex = (idx + 1) % room.players.length;
      room.turn = room.players[room.turnIndex];
      room = await room.save();
      console.log("changing turn blah");
      io.to(name).emit("change-turn", room);
    } else {
      io.to(name).emit("show-leaderboard", room.players);
    }
  });

  socket.on("color-change", async (data) => {
    io.to(data.roomName).emit("color-change", data.color);
  });

  // sending messages in paint screen
  socket.on("msg", async (data) => {
    if (data.msg === data.word) {
      // increment points algorithm = totaltime/timetaken *10 = 30/20
      let room = await Room.find({ name: data.roomName });
      let userPlayer = room[0].players.filter(
        (player) => player.nickname === data.username
      );
      if (data.timeTaken !== 0) {
        userPlayer[0].points += Math.round((200 / data.timeTaken) * 10);
      }
      room = await room[0].save();
      io.to(data.roomName).emit("msg", {
        username: data.username,
        msg: "guessed it!",
        guessedUserCtr: data.guessedUserCtr + 1,
      });
      socket.emit("closeInput", "");
      // not sending points here, will send after every user has guessed
    } else {
      io.to(data.roomName).emit("msg", {
        username: data.username,
        msg: data.msg,
        guessedUserCtr: data.guessedUserCtr,
      });
    }
  });

  socket.on("disconnect", async () => {
    console.log("disconnected");
    let room = await Room.findOne({ "players.socketID": socket.id });
    console.log(room);
    for (let i = 0; i < room.players.length; i++) {
      if (room.players[i].socketID === socket.id) {
        room.players.splice(i, 1);
        break;
      }
    }
    room = await room.save();
    if (room.players.length === 1) {
      socket.broadcast.to(room.name).emit("show-leaderboard", room.players);
    } else {
      socket.broadcast.to(room.name).emit("user-disconnected", room);
    }
  });
});

server.listen(port, () => {
  console.log("server started & running on " + port);
});
