
# Cuadro

A Cross Platform - Web, Android & iOS App multiplayer doodling & guessing game.


## Tech Stack

**Client:** Flutter, socket_io_client

**Server:** Node, Express, Socket.io, Mongoose

  
## Features

- Creating Room
- Joining Room
- Waiting Lobby
- Doodling Features (Everyone In Room Can see)
    - Changing Width of Pen
    - Changing Colour of Pen
    - Clearing off the Screen
    - Drawing
- Generating Random Words
- Chatting In Room
- Identifying Correct Words
- Switching Turns
- Changing Rounds
- Calculating Score
- LeaderBoard


  
## Screenshots

### Mobile
<img src="https://github.com/RivaanRanawat/cuadro/blob/master/screenshots/iphone/MainScreen.png" width="200" />
<img src="https://github.com/RivaanRanawat/cuadro/blob/master/screenshots/iphone/CreateRoomScreen.png" width="200" />
<img src="https://github.com/RivaanRanawat/cuadro/blob/master/screenshots/iphone/JoinRoomScreen.png" width="200" />
<img src="https://github.com/RivaanRanawat/cuadro/blob/master/screenshots/iphone/WaitingLobbyScreen.png" width="200" />
<img src="https://github.com/RivaanRanawat/cuadro/blob/master/screenshots/iphone/DrawerTurn.png" width="200" />
<img src="https://github.com/RivaanRanawat/cuadro/blob/master/screenshots/iphone/RoundComplete.png" width="200" />
<img src="https://github.com/RivaanRanawat/cuadro/blob/master/screenshots/iphone/ScoreBoard.png" width="200" />


### Web
<img src="https://github.com/RivaanRanawat/cuadro/blob/master/screenshots/web/MainScreen.png"/>
<img src="https://github.com/RivaanRanawat/cuadro/blob/master/screenshots/web/CreateRoomScreen.png"/>
<img src="https://github.com/RivaanRanawat/cuadro/blob/master/screenshots/web/JoinRoomScreen.png"/>
<img src="https://github.com/RivaanRanawat/cuadro/blob/master/screenshots/web/WaitingLobbyScreen.png"/>
<img src="https://github.com/RivaanRanawat/cuadro/blob/master/screenshots/web/WordGuessScreen.png"/>
<img src="https://github.com/RivaanRanawat/cuadro/blob/master/screenshots/web/ScoreBoard.png"/>

  
## Environment Variables

To run this project, you will need to add the following environment variables to your .env file

`MONGODB_URL`: `Your MongoDB URI Generated from MongoDB Atlas`

Make sure to replace <yourip> in `lib/screens/paint_screen.dart` with your IP address.

  
## Run Locally

Clone the project

```bash
  git clone https://github.com/RivaanRanawat/cuadro
```

Go to the project directory

```bash
  cd cuadro
```

Install dependencies (Client Side)
```bash
flutter pub get
```

Install dependencies (Server Side)

```bash
cd server && npm install
```

Start the server

```bash
npm run dev
```

  