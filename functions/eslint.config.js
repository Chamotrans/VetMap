"use strict";

module.exports = [
  {
    ignores: ["node_modules/**"],
  },
  {
    files: ["**/*.js"],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "commonjs",
      globals: {
        console: "readonly",
        exports: "writable",
        module: "readonly",
        require: "readonly",
      },
    },
    rules: {
      "eqeqeq": ["error", "always"],
      "no-undef": "error",
      "no-unused-vars": ["error", {"argsIgnorePattern": "^_"}],
      "quotes": ["error", "double", {"avoidEscape": true}],
      "semi": ["error", "always"],
    },
  },
];
