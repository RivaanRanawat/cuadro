const express = require("express");
var http = require("http");
const app = express();
const port = process.env.PORT || 5000;
var server = http.createServer(app);
var io = require("socket.io")(server);
const mongoose = require("mongoose");
const getWord = require("./apis/generateWord");
const Room = require("./models/Room");

//middleware
app.use(express.json());

mongoose
  .connect(
    "mongodb+srv://rivaan:rivaanranawat@cluster0.xbhhc.mongodb.net/myFirstDatabase?retryWrites=true&w=majority",
    {
      useNewUrlParser: true,
      useUnifiedTopology: true,
      useCreateIndex: true,
      useFindAndModify: false,
    }
  )
  .then(() => {
    console.log("connection succesful");
  })
  .catch((e) => {
    console.log(e);
  });

// sockets

io.on("connection", (socket) => {
  console.log("connected");
  console.log(socket.id, "has joined");
  socket.on("test", (data) => {
    console.log(data);
  });

  // white board related sockets
  socket.on("paint", ({ details, roomName }) => {
    console.log(details);
    console.log(roomName);
    io.to(roomName).emit("points", { details: details });
  });

  socket.on("clean-screen", (roomId) => {
    console.log("screen clean");
    io.to(roomId).emit("clear-screen", "");
  });

  socket.on("stroke-width", (stroke) => {
    io.emit("stroke-width", stroke);
  });

  // game related sockets
  // creating game
  socket.on("create-game", async ({ nickname, name, occupancy }) => {
    try {
      const existingRoom = await Room.findOne({ name });
      if (existingRoom) {
        socket.emit("notCorrectGame", "Room with that name already exists");
        return;
      }
      let room = new Room();
      const word = await getWord();
      room.word = word;
      room.name = name;
      room.occupancy = occupancy;
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
    console.log(name, nickname);
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
        console.log(room.players.length);
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
    let room = await Room.findOne({ name });
    room.word = await getWord();
    let idx = room.turnIndex;
    idx += 1;
    room.turn = room.players[idx];
    room = await room.save();
    socket.emit("change-turn", room);
  });

  // sending messages in paint screen
  socket.on("msg", async (data) => {
    console.log(data.username);
    console.log(data.msg);
    if (data.msg === data.word) {
      // increment points algorithm = totaltime/timetaken *10 = 30/20
      let room = await Room.find({ name: data.roomName });
      let userPlayer = room[0].players.filter(
        (player) => player.nickname === data.username
      );
      userPlayer[0].points = Math.round((data.totalTime / data.timeTaken) * 10);
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
});

server.listen(port, "0.0.0.0", () => {
  console.log("server started");
});
