const express = require('express');
const cors = require('cors');
const https = require('https');
const http = require('http');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// AI Chat Proxy Endpoint
app.post('/api/chat', async (req, res) => {
  try {
    const { prompt } = req.body;

    if (!prompt || typeof prompt !== 'string') {
      return res.status(400).json({ 
        error: 'Invalid request: prompt is required and must be a string' 
      });
    }

    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      return res.status(500).json({ 
        error: 'Server configuration error: API key not found' 
      });
    }

    // Prepare Gemini API request - using stable production model
    const geminiEndpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';
    const url = `${geminiEndpoint}?key=${apiKey}`;

    const requestData = {
      contents: [
        {
          parts: [
            {
              text: prompt
            }
          ]
        }
      ],
      generationConfig: {
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 8192
      }
    };

    // Make request to Gemini API
    const options = {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      }
    };

    const protocol = url.startsWith('https') ? https : http;

    const request = protocol.request(url, options, (response) => {
      let data = '';

      response.on('data', (chunk) => {
        data += chunk;
      });

      response.on('end', () => {
        try {
          const jsonResponse = JSON.parse(data);

          // Handle specific HTTP status codes with appropriate error messages
          if (response.statusCode !== 200) {
            console.error('Gemini API Error:', response.statusCode, jsonResponse);
            
            let errorMessage = 'AI service error';
            let userFriendlyMessage = 'Could not reach the AI service. Please try again.';

            switch (response.statusCode) {
              case 400:
                errorMessage = 'Bad request';
                userFriendlyMessage = 'Invalid request format. Please try again.';
                break;
              case 401:
                errorMessage = 'Unauthorized';
                userFriendlyMessage = 'API authentication failed. Please check your API key.';
                break;
              case 403:
                errorMessage = 'Forbidden';
                userFriendlyMessage = 'API access denied. Please check your API key permissions.';
                break;
              case 404:
                errorMessage = 'Model not found';
                userFriendlyMessage = 'AI model is currently unavailable. Please try again later.';
                break;
              case 429:
                errorMessage = 'Rate limit exceeded';
                userFriendlyMessage = 'Too many requests. Please wait a moment and try again.';
                break;
              case 500:
              case 502:
              case 503:
              case 504:
                errorMessage = 'Service unavailable';
                userFriendlyMessage = 'AI service is temporarily unavailable. Please try again later.';
                break;
              default:
                errorMessage = jsonResponse.error?.message || 'Unknown error';
                userFriendlyMessage = `AI service error (${response.statusCode}). Please try again.`;
            }

            return res.status(response.statusCode).json({
              error: errorMessage,
              userMessage: userFriendlyMessage,
              details: jsonResponse.error?.message || 'Unknown error',
              statusCode: response.statusCode
            });
          }

          // Extract the AI response text
          let aiResponse = '';
          if (jsonResponse.candidates && jsonResponse.candidates.length > 0) {
            const candidate = jsonResponse.candidates[0];
            if (candidate.content && candidate.content.parts && candidate.content.parts.length > 0) {
              aiResponse = candidate.content.parts[0].text;
            }
          }

          if (!aiResponse) {
            return res.status(500).json({
              error: 'Failed to extract AI response',
              userMessage: 'AI returned an empty response. Please try again.'
            });
          }

          res.status(200).json({
            response: aiResponse,
            timestamp: new Date().toISOString()
          });

        } catch (parseError) {
          console.error('JSON Parse Error:', parseError);
          res.status(500).json({
            error: 'Failed to parse AI response',
            userMessage: 'Could not process AI response. Please try again.'
          });
        }
      });
    });

    request.on('error', (error) => {
      console.error('Network Error:', error);
      res.status(500).json({
        error: 'Network error while contacting AI service'
      });
    });

    request.write(JSON.stringify(requestData));
    request.end();

  } catch (error) {
    console.error('Server Error:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: error.message
    });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Unhandled Error:', err);
  res.status(500).json({
    error: 'Internal server error',
    message: err.message
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`TutorPDF AI Proxy Server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`API Key configured: ${!!process.env.GEMINI_API_KEY}`);
});

module.exports = app;
