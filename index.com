<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Math Trainer - Basic Facts</title>
    <style>
        body { font-family: 'Segoe UI', sans-serif; background: #fdfdfd; display: flex; justify-content: center; padding: 20px; }
        #app { background: white; padding: 30px; border-radius: 20px; box-shadow: 0 15px 35px rgba(0,0,0,0.1); width: 100%; max-width: 550px; text-align: center; border-top: 8px solid #e67e22; position: relative; }
        .hidden { display: none; }
        button { padding: 12px 24px; cursor: pointer; border-radius: 8px; border: none; background: #e67e22; color: white; font-weight: bold; font-size: 1rem; margin: 5px; }
        .reset-btn { background: #95a5a6; padding: 5px 10px; font-size: 0.8rem; position: absolute; top: 10px; right: 10px; }
        .clue-btn { background: #f39c12; }
        input[type="number"] { font-size: 2.5rem; width: 150px; text-align: center; margin: 15px; border: 3px solid #ddd; border-radius: 10px; }
        input.error { border-color: #e74c3c; background-color: #fdf2f2; }
        #timer-container { width: 100%; height: 12px; background: #eee; border-radius: 6px; overflow: hidden; margin-bottom: 5px; }
        #timer-bar { height: 100%; background: #e74c3c; width: 100%; }
        #progress-text { font-size: 0.9rem; color: #7f8c8d; font-weight: bold; margin-bottom: 15px; }
        #status-msg { font-weight: bold; min-height: 24px; margin-bottom: 10px; }
        .dot { display: inline-block; width: 15px; height: 15px; background: #e67e22; border-radius: 50%; margin: 2px; }
        .ten-frame { border: 2px solid #34495e; display: inline-block; padding: 5px; margin: 5px; border-radius: 5px; background: #ecf0f1; }
        .wrong-text { color: #e74c3c; }
    </style>
</head>
<body>

<div id="app">
    <button id="mini-reset" class="reset-btn hidden" onclick="location.reload()">Start Over</button>

    <div id="setup-screen">
        <h1>Basic Facts Trainer</h1>
        <p>Focusing on Doubles, Near-Doubles, and Bridging 10.</p>
        
        <p>Number of Questions:</p>
        <select id="total-select" style="padding: 10px; width: 100%;">
            <option value="10">10 Questions</option>
            <option value="20" selected>20 Questions</option>
        </select>

        <p>Time per question:</p>
        <select id="time-select" style="padding: 10px; width: 100%;">
            <option value="5">5 Seconds (Expert)</option>
            <option value="10" selected>10 Seconds (Standard)</option>
            <option value="20">20 Seconds (Learning)</option>
        </select>
        <br><br>
        <button onclick="start('add')">Addition Facts (+)</button>
        <button onclick="start('sub')" style="background: #d35400;">Subtraction Facts (-)</button>
    </div>

    <div id="quiz-screen" class="hidden">
        <div id="progress-text">Question 1 of 20</div>
        <div id="timer-container"><div id="timer-bar"></div></div>
        <div id="status-msg"></div>
        <h2 id="question-display" style="font-size: 4rem; margin: 10px 0;"></h2>
        <input type="number" id="user-answer" placeholder="?" autocomplete="off">
        <br>
        <button onclick="checkAnswer()">Submit</button>
        <button class="clue-btn" onclick="showClue()">💡 Clue</button>
        <div id="visual-clue" class="hidden" style="margin-top:20px;"></div>
    </div>

    <div id="result-screen" class="hidden">
        <h2>Great Practice!</h2>
        <p id="final-score" style="font-size: 2.5rem;"></p>
        <button onclick="location.reload()" style="background: #3498db;">Restart</button>
    </div>
</div>

<script>
    let mode = 'add', currentQ = {}, timerInterval, timeLeft, score = 0, count = 0, timerPaused = false, attempts = 0, totalQuestions = 20;

    // These are the "Tricky Facts" students need to master
    const additionPool = [
        [6,6], [7,7], [8,8], [9,9], [12,12], // Doubles
        [6,7], [7,8], [8,9], [9,10],         // Near Doubles
        [8,5], [8,6], [7,5], [7,6], [9,4], [9,5], [9,6], [9,7], [9,8] // Bridge 10
    ];

    document.addEventListener('keypress', (e) => {
        if (e.key === 'Enter' && !document.getElementById('quiz-screen').classList.contains('hidden')) checkAnswer();
    });

    function start(selectedMode) {
        mode = selectedMode;
        totalQuestions = parseInt(document.getElementById('total-select').value);
        document.getElementById('setup-screen').classList.add('hidden');
        document.getElementById('quiz-screen').classList.remove('hidden');
        document.getElementById('mini-reset').classList.remove('hidden');
        generateQuestion();
    }

    function generateQuestion() {
        attempts = 0;
        timerPaused = false;
        document.getElementById('progress-text').innerText = `Question ${count + 1} of ${totalQuestions}`;
        document.getElementById('status-msg').innerHTML = "";
        document.getElementById('user-answer').classList.remove('error');
        document.getElementById('visual-clue').classList.add('hidden');
        document.getElementById('visual-clue').innerHTML = '';
        
        const pair = additionPool[Math.floor(Math.random() * additionPool.length)];
        
        if(mode === 'add') {
            currentQ = { a: pair[0], b: pair[1], ans: pair[0] + pair[1], text: `${pair[0]} + ${pair[1]}` };
        } else {
            // Subtraction: Start with the sum, subtract one part
            let sum = pair[0] + pair[1];
            currentQ = { a: sum, b: pair[0], ans: pair[1], text: `${sum} - ${pair[0]}` };
        }

        document.getElementById('question-display').innerText = currentQ.text;
        document.getElementById('user-answer').value = '';
        document.getElementById('user-answer').focus();
        resetTimer();
    }

    function showClue() {
        timerPaused = true;
        document.getElementById('status-msg').innerHTML = "⏸ Timer Paused";
        const visual = document.getElementById('visual-clue');
        visual.classList.remove('hidden');
        visual.innerHTML = '';

        if(mode === 'add') {
            createDots(currentQ.a, '#e67e22'); // First number
            visual.innerHTML += " <span style='font-size:2rem'>+</span> ";
            createDots(currentQ.b, '#3498db'); // Second number
        } else {
            // For subtraction, show the total, but color the part being taken away
            createDots(currentQ.b, '#ccc'); // The part taken away
            createDots(currentQ.ans, '#e67e22'); // The part remaining
        }
    }

    function createDots(num, color) {
        const visual = document.getElementById('visual-clue');
        let container = document.createElement('div');
        container.className = 'ten-frame';
        for(let i=0; i<num; i++) {
            let d = document.createElement('div');
            d.className = 'dot';
            d.style.backgroundColor = color;
            container.appendChild(d);
        }
        visual.appendChild(container);
    }

    function resetTimer() {
        clearInterval(timerInterval);
        const maxTime = parseInt(document.getElementById('time-select').value);
        timeLeft = maxTime;
        const bar = document.getElementById('timer-bar');
        timerInterval = setInterval(() => {
            if(!timerPaused) {
                timeLeft -= 0.1;
                bar.style.width = (timeLeft / maxTime * 100) + "%";
                if(timeLeft <= 0) {
                    timerPaused = true;
                    document.getElementById('status-msg').innerHTML = "<span class='wrong-text'>⏰ Time's up! Solve it to continue.</span>";
                    showClue();
                }
            }
        }, 100);
    }

    function checkAnswer() {
        const userAns = parseInt(document.getElementById('user-answer').value);
        if(userAns === currentQ.ans) {
            if(attempts === 0 && !timerPaused) score++;
            count++;
            if(count >= totalQuestions) endQuiz();
            else generateQuestion();
        } else {
            attempts++;
            timerPaused = true;
            document.getElementById('user-answer').classList.add('error');
            document.getElementById('status-msg').innerHTML = "<span class='wrong-text'>❌ Try again!</span>";
            if(attempts >= 2) showClue();
        }
    }

    function endQuiz() {
        clearInterval(timerInterval);
        document.getElementById('quiz-screen').classList.add('hidden');
        document.getElementById('result-screen').classList.remove('hidden');
        document.getElementById('final-score').innerText = `${score} / ${totalQuestions}`;
    }
</script>
</body>
</html>
