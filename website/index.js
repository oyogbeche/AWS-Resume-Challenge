function toggleMenu() {
    const navbar2 = document.querySelector(".navbar2");
    navbar2.classList.toggle("show");
}

const counter = document.querySelector(".views");
async function updateCounter() {
    let response = await fetch("https://s9iv3610s5.execute-api.eu-west-1.amazonaws.com/default/views");
    let data = await response.json()
    counter.innerHTML = `This page have been viewed: ${data} times`;
}
updateCounter();