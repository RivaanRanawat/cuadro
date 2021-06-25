const axios = require("axios");

const getWord = async () => {
    const jokeData = await axios.get("https://random-word-form.herokuapp.com/random/animal",)
    return jokeData.data[0];
}

module.exports = getWord;
